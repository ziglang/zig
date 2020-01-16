const builtin = @import("builtin");
const std = @import("../std.zig");
const event = std.event;
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;
const mem = std.mem;
const windows = os.windows;
const Loop = event.Loop;
const fd_t = os.fd_t;
const File = std.fs.File;
const Allocator = mem.Allocator;

//! TODO mege this with `std.fs`

const global_event_loop = Loop.instance orelse
    @compileError("std.event.fs currently only works with event-based I/O");

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
        WriteV: WriteV,
        PWriteV: PWriteV,
        PReadV: PReadV,
        Open: Open,
        Close: Close,
        WriteFile: WriteFile,
        End, // special - means the fs thread should exit

        pub const WriteV = struct {
            fd: fd_t,
            iov: []const os.iovec_const,
            result: Error!void,

            pub const Error = os.WriteError;
        };

        pub const PWriteV = struct {
            fd: fd_t,
            iov: []const os.iovec_const,
            offset: usize,
            result: Error!void,

            pub const Error = os.WriteError;
        };

        pub const PReadV = struct {
            fd: fd_t,
            iov: []const os.iovec,
            offset: usize,
            result: Error!usize,

            pub const Error = os.ReadError;
        };

        pub const Open = struct {
            path: [:0]const u8,
            flags: u32,
            mode: File.Mode,
            result: Error!fd_t,

            pub const Error = File.OpenError;
        };

        pub const WriteFile = struct {
            path: [:0]const u8,
            contents: []const u8,
            mode: File.Mode,
            result: Error!void,

            pub const Error = File.OpenError || File.WriteError;
        };

        pub const Close = struct {
            fd: fd_t,
        };
    };
};

pub const PWriteVError = error{OutOfMemory} || File.WriteError;

/// data - just the inner references - must live until pwritev frame completes.
pub fn pwritev(allocator: *Allocator, fd: fd_t, data: []const []const u8, offset: usize) PWriteVError!void {
    switch (builtin.os) {
        .macosx,
        .linux,
        .freebsd,
        .netbsd,
        .dragonfly,
        => {
            const iovecs = try allocator.alloc(os.iovec_const, data.len);
            defer allocator.free(iovecs);

            for (data) |buf, i| {
                iovecs[i] = os.iovec_const{
                    .iov_base = buf.ptr,
                    .iov_len = buf.len,
                };
            }

            return pwritevPosix(fd, iovecs, offset);
        },
        .windows => {
            const data_copy = try std.mem.dupe(allocator, []const u8, data);
            defer allocator.free(data_copy);
            return pwritevWindows(fd, data, offset);
        },
        else => @compileError("Unsupported OS"),
    }
}

/// data must outlive the returned frame
pub fn pwritevWindows(fd: fd_t, data: []const []const u8, offset: usize) os.WindowsWriteError!void {
    if (data.len == 0) return;
    if (data.len == 1) return pwriteWindows(fd, data[0], offset);

    // TODO do these in parallel
    var off = offset;
    for (data) |buf| {
        try pwriteWindows(fd, buf, off);
        off += buf.len;
    }
}

pub fn pwriteWindows(fd: fd_t, data: []const u8, offset: u64) os.WindowsWriteError!void {
    var resume_node = Loop.ResumeNode.Basic{
        .base = Loop.ResumeNode{
            .id = Loop.ResumeNode.Id.Basic,
            .handle = @frame(),
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
    _ = windows.CreateIoCompletionPort(fd, global_event_loop.os_data.io_port, undefined, undefined);
    global_event_loop.beginOneEvent();
    errdefer global_event_loop.finishOneEvent();

    errdefer {
        _ = windows.kernel32.CancelIoEx(fd, &resume_node.base.overlapped);
    }
    suspend {
        _ = windows.kernel32.WriteFile(fd, data.ptr, @intCast(windows.DWORD, data.len), null, &resume_node.base.overlapped);
    }
    var bytes_transferred: windows.DWORD = undefined;
    if (windows.kernel32.GetOverlappedResult(fd, &resume_node.base.overlapped, &bytes_transferred, windows.FALSE) == 0) {
        switch (windows.kernel32.GetLastError()) {
            windows.ERROR.IO_PENDING => unreachable,
            windows.ERROR.INVALID_USER_BUFFER => return error.SystemResources,
            windows.ERROR.NOT_ENOUGH_MEMORY => return error.SystemResources,
            windows.ERROR.OPERATION_ABORTED => return error.OperationAborted,
            windows.ERROR.NOT_ENOUGH_QUOTA => return error.SystemResources,
            windows.ERROR.BROKEN_PIPE => return error.BrokenPipe,
            else => |err| return windows.unexpectedError(err),
        }
    }
}

/// iovecs must live until pwritev frame completes.
pub fn pwritevPosix(fd: fd_t, iovecs: []const os.iovec_const, offset: usize) os.WriteError!void {
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
                    .data = @frame(),
                },
            },
        },
    };

    errdefer global_event_loop.posixFsCancel(&req_node);

    suspend {
        global_event_loop.posixFsRequest(&req_node);
    }

    return req_node.data.msg.PWriteV.result;
}

/// iovecs must live until pwritev frame completes.
pub fn writevPosix(fd: fd_t, iovecs: []const os.iovec_const) os.WriteError!void {
    var req_node = RequestNode{
        .prev = null,
        .next = null,
        .data = Request{
            .msg = Request.Msg{
                .WriteV = Request.Msg.WriteV{
                    .fd = fd,
                    .iov = iovecs,
                    .result = undefined,
                },
            },
            .finish = Request.Finish{
                .TickNode = Loop.NextTickNode{
                    .prev = null,
                    .next = null,
                    .data = @frame(),
                },
            },
        },
    };

    suspend {
        global_event_loop.posixFsRequest(&req_node);
    }

    return req_node.data.msg.WriteV.result;
}

pub const PReadVError = error{OutOfMemory} || File.ReadError;

/// data - just the inner references - must live until preadv frame completes.
pub fn preadv(allocator: *Allocator, fd: fd_t, data: []const []u8, offset: usize) PReadVError!usize {
    assert(data.len != 0);
    switch (builtin.os) {
        .macosx,
        .linux,
        .freebsd,
        .netbsd,
        .dragonfly,
        => {
            const iovecs = try allocator.alloc(os.iovec, data.len);
            defer allocator.free(iovecs);

            for (data) |buf, i| {
                iovecs[i] = os.iovec{
                    .iov_base = buf.ptr,
                    .iov_len = buf.len,
                };
            }

            return preadvPosix(fd, iovecs, offset);
        },
        .windows => {
            const data_copy = try std.mem.dupe(allocator, []u8, data);
            defer allocator.free(data_copy);
            return preadvWindows(fd, data_copy, offset);
        },
        else => @compileError("Unsupported OS"),
    }
}

/// data must outlive the returned frame
pub fn preadvWindows(fd: fd_t, data: []const []u8, offset: u64) !usize {
    assert(data.len != 0);
    if (data.len == 1) return preadWindows(fd, data[0], offset);

    // TODO do these in parallel?
    var off: usize = 0;
    var iov_i: usize = 0;
    var inner_off: usize = 0;
    while (true) {
        const v = data[iov_i];
        const amt_read = try preadWindows(fd, v[inner_off .. v.len - inner_off], offset + off);
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

pub fn preadWindows(fd: fd_t, data: []u8, offset: u64) !usize {
    var resume_node = Loop.ResumeNode.Basic{
        .base = Loop.ResumeNode{
            .id = Loop.ResumeNode.Id.Basic,
            .handle = @frame(),
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
    _ = windows.CreateIoCompletionPort(fd, global_event_loop.os_data.io_port, undefined, undefined) catch undefined;
    global_event_loop.beginOneEvent();
    errdefer global_event_loop.finishOneEvent();

    errdefer {
        _ = windows.kernel32.CancelIoEx(fd, &resume_node.base.overlapped);
    }
    suspend {
        _ = windows.kernel32.ReadFile(fd, data.ptr, @intCast(windows.DWORD, data.len), null, &resume_node.base.overlapped);
    }
    var bytes_transferred: windows.DWORD = undefined;
    if (windows.kernel32.GetOverlappedResult(fd, &resume_node.base.overlapped, &bytes_transferred, windows.FALSE) == 0) {
        switch (windows.kernel32.GetLastError()) {
            windows.ERROR.IO_PENDING => unreachable,
            windows.ERROR.OPERATION_ABORTED => return error.OperationAborted,
            windows.ERROR.BROKEN_PIPE => return error.BrokenPipe,
            windows.ERROR.HANDLE_EOF => return @as(usize, bytes_transferred),
            else => |err| return windows.unexpectedError(err),
        }
    }
    return @as(usize, bytes_transferred);
}

/// iovecs must live until preadv frame completes
pub fn preadvPosix(fd: fd_t, iovecs: []const os.iovec, offset: usize) os.ReadError!usize {
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
                    .data = @frame(),
                },
            },
        },
    };

    errdefer global_event_loop.posixFsCancel(&req_node);

    suspend {
        global_event_loop.posixFsRequest(&req_node);
    }

    return req_node.data.msg.PReadV.result;
}

pub fn openPosix(path: []const u8, flags: u32, mode: File.Mode) File.OpenError!fd_t {
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
                    .data = @frame(),
                },
            },
        },
    };

    errdefer global_event_loop.posixFsCancel(&req_node);

    suspend {
        global_event_loop.posixFsRequest(&req_node);
    }

    return req_node.data.msg.Open.result;
}

pub fn openRead(path: []const u8) File.OpenError!fd_t {
    switch (builtin.os) {
        .macosx, .linux, .freebsd, .netbsd, .dragonfly => {
            const O_LARGEFILE = if (@hasDecl(os, "O_LARGEFILE")) os.O_LARGEFILE else 0;
            const flags = O_LARGEFILE | os.O_RDONLY | os.O_CLOEXEC;
            return openPosix(path, flags, File.default_mode);
        },

        .windows => return windows.CreateFile(
            path,
            windows.GENERIC_READ,
            windows.FILE_SHARE_READ,
            null,
            windows.OPEN_EXISTING,
            windows.FILE_ATTRIBUTE_NORMAL | windows.FILE_FLAG_OVERLAPPED,
            null,
        ),

        else => @compileError("Unsupported OS"),
    }
}

/// Creates if does not exist. Truncates the file if it exists.
/// Uses the default mode.
pub fn openWrite(path: []const u8) File.OpenError!fd_t {
    return openWriteMode(path, File.default_mode);
}

/// Creates if does not exist. Truncates the file if it exists.
pub fn openWriteMode(path: []const u8, mode: File.Mode) File.OpenError!fd_t {
    switch (builtin.os) {
        .macosx,
        .linux,
        .freebsd,
        .netbsd,
        .dragonfly,
        => {
            const O_LARGEFILE = if (@hasDecl(os, "O_LARGEFILE")) os.O_LARGEFILE else 0;
            const flags = O_LARGEFILE | os.O_WRONLY | os.O_CREAT | os.O_CLOEXEC | os.O_TRUNC;
            return openPosix(path, flags, File.default_mode);
        },
        .windows => return windows.CreateFile(
            path,
            windows.GENERIC_WRITE,
            windows.FILE_SHARE_WRITE | windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE,
            null,
            windows.CREATE_ALWAYS,
            windows.FILE_ATTRIBUTE_NORMAL | windows.FILE_FLAG_OVERLAPPED,
            null,
        ),
        else => @compileError("Unsupported OS"),
    }
}

/// Creates if does not exist. Does not truncate.
pub fn openReadWrite(path: []const u8, mode: File.Mode) File.OpenError!fd_t {
    switch (builtin.os) {
        .macosx, .linux, .freebsd, .netbsd, .dragonfly => {
            const O_LARGEFILE = if (@hasDecl(os, "O_LARGEFILE")) os.O_LARGEFILE else 0;
            const flags = O_LARGEFILE | os.O_RDWR | os.O_CREAT | os.O_CLOEXEC;
            return openPosix(path, flags, mode);
        },

        .windows => return windows.CreateFile(
            path,
            windows.GENERIC_WRITE | windows.GENERIC_READ,
            windows.FILE_SHARE_WRITE | windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE,
            null,
            windows.OPEN_ALWAYS,
            windows.FILE_ATTRIBUTE_NORMAL | windows.FILE_FLAG_OVERLAPPED,
            null,
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
    allocator: *Allocator,
    os_data: OsData,

    const OsData = switch (builtin.os) {
        .linux, .macosx, .freebsd, .netbsd, .dragonfly => OsDataPosix,

        .windows => struct {
            handle: ?fd_t,
        },

        else => @compileError("Unsupported OS"),
    };

    const OsDataPosix = struct {
        have_fd: bool,
        close_req_node: RequestNode,
    };

    pub fn start(allocator: *Allocator) (error{OutOfMemory}!*CloseOperation) {
        const self = try allocator.create(CloseOperation);
        self.* = CloseOperation{
            .allocator = allocator,
            .os_data = switch (builtin.os) {
                .linux, .macosx, .freebsd, .netbsd, .dragonfly => initOsDataPosix(self),
                .windows => OsData{ .handle = null },
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
            .linux,
            .macosx,
            .freebsd,
            .netbsd,
            .dragonfly,
            => {
                if (self.os_data.have_fd) {
                    global_event_loop.posixFsRequest(&self.os_data.close_req_node);
                } else {
                    self.allocator.destroy(self);
                }
            },
            .windows => {
                if (self.os_data.handle) |handle| {
                    os.close(handle);
                }
                self.allocator.destroy(self);
            },
            else => @compileError("Unsupported OS"),
        }
    }

    pub fn setHandle(self: *CloseOperation, handle: fd_t) void {
        switch (builtin.os) {
            .linux,
            .macosx,
            .freebsd,
            .netbsd,
            .dragonfly,
            => {
                self.os_data.close_req_node.data.msg.Close.fd = handle;
                self.os_data.have_fd = true;
            },
            .windows => {
                self.os_data.handle = handle;
            },
            else => @compileError("Unsupported OS"),
        }
    }

    /// Undo a `setHandle`.
    pub fn clearHandle(self: *CloseOperation) void {
        switch (builtin.os) {
            .linux,
            .macosx,
            .freebsd,
            .netbsd,
            .dragonfly,
            => {
                self.os_data.have_fd = false;
            },
            .windows => {
                self.os_data.handle = null;
            },
            else => @compileError("Unsupported OS"),
        }
    }

    pub fn getHandle(self: *CloseOperation) fd_t {
        switch (builtin.os) {
            .linux,
            .macosx,
            .freebsd,
            .netbsd,
            .dragonfly,
            => {
                assert(self.os_data.have_fd);
                return self.os_data.close_req_node.data.msg.Close.fd;
            },
            .windows => {
                return self.os_data.handle.?;
            },
            else => @compileError("Unsupported OS"),
        }
    }
};

/// contents must remain alive until writeFile completes.
/// TODO make this atomic or provide writeFileAtomic and rename this one to writeFileTruncate
pub fn writeFile(allocator: *Allocator, path: []const u8, contents: []const u8) !void {
    return writeFileMode(allocator, path, contents, File.default_mode);
}

/// contents must remain alive until writeFile completes.
pub fn writeFileMode(allocator: *Allocator, path: []const u8, contents: []const u8, mode: File.Mode) !void {
    switch (builtin.os) {
        .linux,
        .macosx,
        .freebsd,
        .netbsd,
        .dragonfly,
        => return writeFileModeThread(allocator, path, contents, mode),
        .windows => return writeFileWindows(path, contents),
        else => @compileError("Unsupported OS"),
    }
}

fn writeFileWindows(path: []const u8, contents: []const u8) !void {
    const handle = try windows.CreateFile(
        path,
        windows.GENERIC_WRITE,
        windows.FILE_SHARE_WRITE | windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE,
        null,
        windows.CREATE_ALWAYS,
        windows.FILE_ATTRIBUTE_NORMAL | windows.FILE_FLAG_OVERLAPPED,
        null,
    );
    defer os.close(handle);

    try pwriteWindows(handle, contents, 0);
}

fn writeFileModeThread(allocator: *Allocator, path: []const u8, contents: []const u8, mode: File.Mode) !void {
    const path_with_null = try std.cstr.addNullByte(allocator, path);
    defer allocator.free(path_with_null);

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
                    .data = @frame(),
                },
            },
        },
    };

    errdefer global_event_loop.posixFsCancel(&req_node);

    suspend {
        global_event_loop.posixFsRequest(&req_node);
    }

    return req_node.data.msg.WriteFile.result;
}

/// The frame resumes when the last data has been confirmed written, but before the file handle
/// is closed.
/// Caller owns returned memory.
pub fn readFile(allocator: *Allocator, file_path: []const u8, max_size: usize) ![]u8 {
    var close_op = try CloseOperation.start(allocator);
    defer close_op.finish();

    const fd = try openRead(file_path);
    close_op.setHandle(fd);

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    while (true) {
        try list.ensureCapacity(list.len + mem.page_size);
        const buf = list.items[list.len..];
        const buf_array = [_][]u8{buf};
        const amt = try preadv(allocator, fd, &buf_array, list.len);
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

fn eqlString(a: []const u16, b: []const u16) bool {
    if (a.len != b.len) return false;
    if (a.ptr == b.ptr) return true;
    return mem.compare(u16, a, b) == .Equal;
}

fn hashString(s: []const u16) u32 {
    return @truncate(u32, std.hash.Wyhash.hash(0, @sliceToBytes(s)));
}

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
        allocator: *Allocator,

        const OsData = switch (builtin.os) {
            // TODO https://github.com/ziglang/zig/issues/3778
            .macosx, .freebsd, .netbsd, .dragonfly => KqOsData,
            .linux => LinuxOsData,
            .windows => WindowsOsData,

            else => @compileError("Unsupported OS"),
        };

        const KqOsData = struct {
            file_table: FileTable,
            table_lock: event.Lock,

            const FileTable = std.StringHashMap(*Put);
            const Put = struct {
                putter_frame: @Frame(kqPutEvents),
                cancelled: bool = false,
                value: V,
            };
        };

        const WindowsOsData = struct {
            table_lock: event.Lock,
            dir_table: DirTable,
            all_putters: std.atomic.Queue(Put),
            ref_count: std.atomic.Int(usize),

            const Put = struct {
                putter: anyframe,
                cancelled: bool = false,
            };

            const DirTable = std.StringHashMap(*Dir);
            const FileTable = std.HashMap([]const u16, V, hashString, eqlString);

            const Dir = struct {
                putter_frame: @Frame(windowsDirReader),
                file_table: FileTable,
                table_lock: event.Lock,
            };
        };

        const LinuxOsData = struct {
            putter_frame: @Frame(linuxEventPutter),
            inotify_fd: i32,
            wd_table: WdTable,
            table_lock: event.Lock,
            cancelled: bool = false,

            const WdTable = std.AutoHashMap(i32, Dir);
            const FileTable = std.StringHashMap(V);

            const Dir = struct {
                dirname: []const u8,
                file_table: FileTable,
            };
        };

        const Self = @This();

        pub const Event = struct {
            id: Id,
            data: V,

            pub const Id = WatchEventId;
            pub const Error = WatchEventError;
        };

        pub fn init(allocator: *Allocator, event_buf_count: usize) !*Self {
            const channel = try allocator.create(event.Channel(Event.Error!Event));
            errdefer allocator.destroy(channel);
            var buf = try allocator.alloc(Event.Error!Event, event_buf_count);
            errdefer allocator.free(buf);
            channel.init(buf);
            errdefer channel.deinit();

            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            switch (builtin.os) {
                .linux => {
                    const inotify_fd = try os.inotify_init1(os.linux.IN_NONBLOCK | os.linux.IN_CLOEXEC);
                    errdefer os.close(inotify_fd);

                    self.* = Self{
                        .allocator = allocator,
                        .channel = channel,
                        .os_data = OsData{
                            .putter_frame = undefined,
                            .inotify_fd = inotify_fd,
                            .wd_table = OsData.WdTable.init(allocator),
                            .table_lock = event.Lock.init(),
                        },
                    };

                    self.os_data.putter_frame = async self.linuxEventPutter();
                    return self;
                },

                .windows => {
                    self.* = Self{
                        .allocator = allocator,
                        .channel = channel,
                        .os_data = OsData{
                            .table_lock = event.Lock.init(),
                            .dir_table = OsData.DirTable.init(allocator),
                            .ref_count = std.atomic.Int(usize).init(1),
                            .all_putters = std.atomic.Queue(anyframe).init(),
                        },
                    };
                    return self;
                },

                .macosx, .freebsd, .netbsd, .dragonfly => {
                    self.* = Self{
                        .allocator = allocator,
                        .channel = channel,
                        .os_data = OsData{
                            .table_lock = event.Lock.init(),
                            .file_table = OsData.FileTable.init(allocator),
                        },
                    };
                    return self;
                },
                else => @compileError("Unsupported OS"),
            }
        }

        /// All addFile calls and removeFile calls must have completed.
        pub fn deinit(self: *Self) void {
            switch (builtin.os) {
                .macosx, .freebsd, .netbsd, .dragonfly => {
                    // TODO we need to cancel the frames before destroying the lock
                    self.os_data.table_lock.deinit();
                    var it = self.os_data.file_table.iterator();
                    while (it.next()) |entry| {
                        entry.cancelled = true;
                        await entry.value.putter;
                        self.allocator.free(entry.key);
                        self.allocator.free(entry.value);
                    }
                    self.channel.deinit();
                    self.allocator.destroy(self.channel.buffer_nodes);
                    self.allocator.destroy(self);
                },
                .linux => {
                    self.os_data.cancelled = true;
                    await self.os_data.putter_frame;
                    self.allocator.destroy(self);
                },
                .windows => {
                    while (self.os_data.all_putters.get()) |putter_node| {
                        putter_node.cancelled = true;
                        await putter_node.frame;
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
                self.os_data.table_lock.deinit();
                var it = self.os_data.dir_table.iterator();
                while (it.next()) |entry| {
                    self.allocator.free(entry.key);
                    self.allocator.destroy(entry.value);
                }
                self.os_data.dir_table.deinit();
                self.channel.deinit();
                self.allocator.destroy(self.channel.buffer_nodes);
                self.allocator.destroy(self);
            }
        }

        pub fn addFile(self: *Self, file_path: []const u8, value: V) !?V {
            switch (builtin.os) {
                .macosx, .freebsd, .netbsd, .dragonfly => return addFileKEvent(self, file_path, value),
                .linux => return addFileLinux(self, file_path, value),
                .windows => return addFileWindows(self, file_path, value),
                else => @compileError("Unsupported OS"),
            }
        }

        fn addFileKEvent(self: *Self, file_path: []const u8, value: V) !?V {
            const resolved_path = try std.fs.path.resolve(self.allocator, [_][]const u8{file_path});
            var resolved_path_consumed = false;
            defer if (!resolved_path_consumed) self.allocator.free(resolved_path);

            var close_op = try CloseOperation.start(self.allocator);
            var close_op_consumed = false;
            defer if (!close_op_consumed) close_op.finish();

            const flags = if (comptime std.Target.current.isDarwin()) os.O_SYMLINK | os.O_EVTONLY else 0;
            const mode = 0;
            const fd = try openPosix(self.allocator, resolved_path, flags, mode);
            close_op.setHandle(fd);

            var put = try self.allocator.create(OsData.Put);
            errdefer self.allocator.destroy(put);
            put.* = OsData.Put{
                .value = value,
                .putter_frame = undefined,
            };
            put.putter_frame = async self.kqPutEvents(close_op, put);
            close_op_consumed = true;
            errdefer {
                put.cancelled = true;
                await put.putter_frame;
            }

            const result = blk: {
                const held = self.os_data.table_lock.acquire();
                defer held.release();

                const gop = try self.os_data.file_table.getOrPut(resolved_path);
                if (gop.found_existing) {
                    const prev_value = gop.kv.value.value;
                    await gop.kv.value.putter_frame;
                    gop.kv.value = put;
                    break :blk prev_value;
                } else {
                    resolved_path_consumed = true;
                    gop.kv.value = put;
                    break :blk null;
                }
            };

            return result;
        }

        fn kqPutEvents(self: *Self, close_op: *CloseOperation, put: *OsData.Put) void {
            global_event_loop.beginOneEvent();

            defer {
                close_op.finish();
                global_event_loop.finishOneEvent();
            }

            while (!put.cancelled) {
                if (global_event_loop.bsdWaitKev(
                    @intCast(usize, close_op.getHandle()),
                    os.EVFILT_VNODE,
                    os.NOTE_WRITE | os.NOTE_DELETE,
                )) |kev| {
                    // TODO handle EV_ERROR
                    if (kev.fflags & os.NOTE_DELETE != 0) {
                        self.channel.put(Self.Event{
                            .id = Event.Id.Delete,
                            .data = put.value,
                        });
                    } else if (kev.fflags & os.NOTE_WRITE != 0) {
                        self.channel.put(Self.Event{
                            .id = Event.Id.CloseWrite,
                            .data = put.value,
                        });
                    }
                } else |err| switch (err) {
                    error.EventNotFound => unreachable,
                    error.ProcessNotFound => unreachable,
                    error.Overflow => unreachable,
                    error.AccessDenied, error.SystemResources => |casted_err| {
                        self.channel.put(casted_err);
                    },
                }
            }
        }

        fn addFileLinux(self: *Self, file_path: []const u8, value: V) !?V {
            const dirname = std.fs.path.dirname(file_path) orelse ".";
            const dirname_with_null = try std.cstr.addNullByte(self.allocator, dirname);
            var dirname_with_null_consumed = false;
            defer if (!dirname_with_null_consumed) self.channel.free(dirname_with_null);

            const basename = std.fs.path.basename(file_path);
            const basename_with_null = try std.cstr.addNullByte(self.allocator, basename);
            var basename_with_null_consumed = false;
            defer if (!basename_with_null_consumed) self.allocator.free(basename_with_null);

            const wd = try os.inotify_add_watchC(
                self.os_data.inotify_fd,
                dirname_with_null.ptr,
                os.linux.IN_CLOSE_WRITE | os.linux.IN_ONLYDIR | os.linux.IN_EXCL_UNLINK,
            );
            // wd is either a newly created watch or an existing one.

            const held = self.os_data.table_lock.acquire();
            defer held.release();

            const gop = try self.os_data.wd_table.getOrPut(wd);
            if (!gop.found_existing) {
                gop.kv.value = OsData.Dir{
                    .dirname = dirname_with_null,
                    .file_table = OsData.FileTable.init(self.allocator),
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

        fn addFileWindows(self: *Self, file_path: []const u8, value: V) !?V {
            // TODO we might need to convert dirname and basename to canonical file paths ("short"?)
            const dirname = try std.mem.dupe(self.allocator, u8, std.fs.path.dirname(file_path) orelse ".");
            var dirname_consumed = false;
            defer if (!dirname_consumed) self.allocator.free(dirname);

            const dirname_utf16le = try std.unicode.utf8ToUtf16LeWithNull(self.allocator, dirname);
            defer self.allocator.free(dirname_utf16le);

            // TODO https://github.com/ziglang/zig/issues/265
            const basename = std.fs.path.basename(file_path);
            const basename_utf16le_null = try std.unicode.utf8ToUtf16LeWithNull(self.allocator, basename);
            var basename_utf16le_null_consumed = false;
            defer if (!basename_utf16le_null_consumed) self.allocator.free(basename_utf16le_null);
            const basename_utf16le_no_null = basename_utf16le_null[0 .. basename_utf16le_null.len - 1];

            const dir_handle = try windows.CreateFileW(
                dirname_utf16le.ptr,
                windows.FILE_LIST_DIRECTORY,
                windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE | windows.FILE_SHARE_WRITE,
                null,
                windows.OPEN_EXISTING,
                windows.FILE_FLAG_BACKUP_SEMANTICS | windows.FILE_FLAG_OVERLAPPED,
                null,
            );
            var dir_handle_consumed = false;
            defer if (!dir_handle_consumed) windows.CloseHandle(dir_handle);

            const held = self.os_data.table_lock.acquire();
            defer held.release();

            const gop = try self.os_data.dir_table.getOrPut(dirname);
            if (gop.found_existing) {
                const dir = gop.kv.value;
                const held_dir_lock = dir.table_lock.acquire();
                defer held_dir_lock.release();

                const file_gop = try dir.file_table.getOrPut(basename_utf16le_no_null);
                if (file_gop.found_existing) {
                    const prev_value = file_gop.kv.value;
                    file_gop.kv.value = value;
                    return prev_value;
                } else {
                    file_gop.kv.value = value;
                    basename_utf16le_null_consumed = true;
                    return null;
                }
            } else {
                errdefer _ = self.os_data.dir_table.remove(dirname);
                const dir = try self.allocator.create(OsData.Dir);
                errdefer self.allocator.destroy(dir);

                dir.* = OsData.Dir{
                    .file_table = OsData.FileTable.init(self.allocator),
                    .table_lock = event.Lock.init(),
                    .putter_frame = undefined,
                };
                gop.kv.value = dir;
                assert((try dir.file_table.put(basename_utf16le_no_null, value)) == null);
                basename_utf16le_null_consumed = true;

                dir.putter_frame = async self.windowsDirReader(dir_handle, dir);
                dir_handle_consumed = true;

                dirname_consumed = true;

                return null;
            }
        }

        fn windowsDirReader(self: *Self, dir_handle: windows.HANDLE, dir: *OsData.Dir) void {
            self.ref();
            defer self.deref();

            defer os.close(dir_handle);

            var putter_node = std.atomic.Queue(anyframe).Node{
                .data = .{ .putter = @frame() },
                .prev = null,
                .next = null,
            };
            self.os_data.all_putters.put(&putter_node);
            defer _ = self.os_data.all_putters.remove(&putter_node);

            var resume_node = Loop.ResumeNode.Basic{
                .base = Loop.ResumeNode{
                    .id = Loop.ResumeNode.Id.Basic,
                    .handle = @frame(),
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
            _ = windows.CreateIoCompletionPort(
                dir_handle,
                global_event_loop.os_data.io_port,
                undefined,
                undefined,
            ) catch |err| {
                self.channel.put(err);
                return;
            };

            while (!putter_node.data.cancelled) {
                {
                    // TODO only 1 beginOneEvent for the whole function
                    global_event_loop.beginOneEvent();
                    errdefer global_event_loop.finishOneEvent();
                    errdefer {
                        _ = windows.kernel32.CancelIoEx(dir_handle, &resume_node.base.overlapped);
                    }
                    suspend {
                        _ = windows.kernel32.ReadDirectoryChangesW(
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
                if (windows.kernel32.GetOverlappedResult(dir_handle, &resume_node.base.overlapped, &bytes_transferred, windows.FALSE) == 0) {
                    const err = switch (windows.kernel32.GetLastError()) {
                        else => |err| windows.unexpectedError(err),
                    };
                    self.channel.put(err);
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
                                const held = dir.table_lock.acquire();
                                defer held.release();

                                if (dir.file_table.get(basename_utf16le)) |entry| {
                                    break :blk entry.value;
                                } else {
                                    break :blk null;
                                }
                            };
                            if (user_value) |v| {
                                self.channel.put(Event{
                                    .id = id,
                                    .data = v,
                                });
                            }
                        }
                        if (ev.NextEntryOffset == 0) break;
                    }
                }
            }
        }

        pub fn removeFile(self: *Self, file_path: []const u8) ?V {
            @panic("TODO");
        }

        fn linuxEventPutter(self: *Self) void {
            global_event_loop.beginOneEvent();

            defer {
                self.os_data.table_lock.deinit();
                var wd_it = self.os_data.wd_table.iterator();
                while (wd_it.next()) |wd_entry| {
                    var file_it = wd_entry.value.file_table.iterator();
                    while (file_it.next()) |file_entry| {
                        self.allocator.free(file_entry.key);
                    }
                    self.allocator.free(wd_entry.value.dirname);
                    wd_entry.value.file_table.deinit();
                }
                self.os_data.wd_table.deinit();
                global_event_loop.finishOneEvent();
                os.close(self.os_data.inotify_fd);
                self.channel.deinit();
                self.allocator.free(self.channel.buffer_nodes);
            }

            var event_buf: [4096]u8 align(@alignOf(os.linux.inotify_event)) = undefined;

            while (!self.os_data.cancelled) {
                const rc = os.linux.read(self.os_data.inotify_fd, &event_buf, event_buf.len);
                const errno = os.linux.getErrno(rc);
                switch (errno) {
                    0 => {
                        // can't use @bytesToSlice because of the special variable length name field
                        var ptr = event_buf[0..].ptr;
                        const end_ptr = ptr + event_buf.len;
                        var ev: *os.linux.inotify_event = undefined;
                        while (@ptrToInt(ptr) < @ptrToInt(end_ptr)) {
                            ev = @ptrCast(*os.linux.inotify_event, ptr);
                            if (ev.mask & os.linux.IN_CLOSE_WRITE == os.linux.IN_CLOSE_WRITE) {
                                const basename_ptr = ptr + @sizeOf(os.linux.inotify_event);
                                // `ev.len` counts all bytes in `ev.name` including terminating null byte.
                                const basename_with_null = basename_ptr[0..ev.len];
                                const user_value = blk: {
                                    const held = self.os_data.table_lock.acquire();
                                    defer held.release();

                                    const dir = &self.os_data.wd_table.get(ev.wd).?.value;
                                    if (dir.file_table.get(basename_with_null)) |entry| {
                                        break :blk entry.value;
                                    } else {
                                        break :blk null;
                                    }
                                };
                                if (user_value) |v| {
                                    self.channel.put(Event{
                                        .id = WatchEventId.CloseWrite,
                                        .data = v,
                                    });
                                }
                            }

                            ptr = @alignCast(@alignOf(os.linux.inotify_event), ptr + @sizeOf(os.linux.inotify_event) + ev.len);
                        }
                    },
                    os.linux.EINTR => continue,
                    os.linux.EINVAL => unreachable,
                    os.linux.EFAULT => unreachable,
                    os.linux.EAGAIN => {
                        global_event_loop.linuxWaitFd(self.os_data.inotify_fd, os.linux.EPOLLET | os.linux.EPOLLIN | os.EPOLLONESHOT);
                    },
                    else => unreachable,
                }
            }
        }
    };
}

const test_tmp_dir = "std_event_fs_test";

test "write a file, watch it, write it again" {
    // TODO provide a way to run tests in evented I/O mode
    if (!std.io.is_async) return error.SkipZigTest;

    const allocator = std.heap.page_allocator;

    // TODO move this into event loop too
    try os.makePath(allocator, test_tmp_dir);
    defer os.deleteTree(test_tmp_dir) catch {};

    return testFsWatch(&allocator);
}

fn testFsWatch(allocator: *Allocator) !void {
    const file_path = try std.fs.path.join(allocator, [_][]const u8{ test_tmp_dir, "file.txt" });
    defer allocator.free(file_path);

    const contents =
        \\line 1
        \\line 2
    ;
    const line2_offset = 7;

    // first just write then read the file
    try writeFile(allocator, file_path, contents);

    const read_contents = try readFile(allocator, file_path, 1024 * 1024);
    testing.expectEqualSlices(u8, contents, read_contents);

    // now watch the file
    var watch = try Watch(void).init(allocator, 0);
    defer watch.deinit();

    testing.expect((try watch.addFile(file_path, {})) == null);

    const ev = watch.channel.get();
    var ev_consumed = false;
    defer if (!ev_consumed) await ev;

    // overwrite line 2
    const fd = try await openReadWrite(file_path, File.default_mode);
    {
        defer os.close(fd);

        try pwritev(allocator, fd, []const []const u8{"lorem ipsum"}, line2_offset);
    }

    ev_consumed = true;
    switch ((try await ev).id) {
        WatchEventId.CloseWrite => {},
        WatchEventId.Delete => @panic("wrong event"),
    }
    const contents_updated = try readFile(allocator, file_path, 1024 * 1024);
    testing.expectEqualSlices(u8,
        \\line 1
        \\lorem ipsum
    , contents_updated);

    // TODO test deleting the file and then re-adding it. we should get events for both
}

pub const OutStream = struct {
    fd: fd_t,
    stream: Stream,
    allocator: *Allocator,
    offset: usize,

    pub const Error = File.WriteError;
    pub const Stream = event.io.OutStream(Error);

    pub fn init(allocator: *Allocator, fd: fd_t, offset: usize) OutStream {
        return OutStream{
            .fd = fd,
            .offset = offset,
            .stream = Stream{ .writeFn = writeFn },
        };
    }

    fn writeFn(out_stream: *Stream, bytes: []const u8) Error!void {
        const self = @fieldParentPtr(OutStream, "stream", out_stream);
        const offset = self.offset;
        self.offset += bytes.len;
        return pwritev(self.allocator, self.fd, [_][]const u8{bytes}, offset);
    }
};

pub const InStream = struct {
    fd: fd_t,
    stream: Stream,
    allocator: *Allocator,
    offset: usize,

    pub const Error = PReadVError; // TODO make this not have OutOfMemory
    pub const Stream = event.io.InStream(Error);

    pub fn init(allocator: *Allocator, fd: fd_t, offset: usize) InStream {
        return InStream{
            .fd = fd,
            .offset = offset,
            .stream = Stream{ .readFn = readFn },
        };
    }

    fn readFn(in_stream: *Stream, bytes: []u8) Error!usize {
        const self = @fieldParentPtr(InStream, "stream", in_stream);
        const amt = try preadv(self.allocator, self.fd, [_][]u8{bytes}, self.offset);
        self.offset += amt;
        return amt;
    }
};
