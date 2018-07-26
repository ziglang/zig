const std = @import("../index.zig");
const event = std.event;
const assert = std.debug.assert;
const os = std.os;
const mem = std.mem;

pub const RequestNode = std.atomic.Queue(Request).Node;

pub const Request = struct {
    msg: Msg,
    finish: Finish,

    pub const Finish = union(enum) {
        TickNode: event.Loop.NextTickNode,
        DeallocCloseOperation: *CloseOperation,
        NoAction,
    };

    pub const Msg = union(enum) {
        PWriteV: PWriteV,
        PReadV: PReadV,
        OpenRead: OpenRead,
        Close: Close,
        WriteFile: WriteFile,
        End, // special - means the fs thread should exit

        pub const PWriteV = struct {
            fd: os.FileHandle,
            data: []const []const u8,
            offset: usize,
            result: Error!void,

            pub const Error = error{};
        };

        pub const PReadV = struct {
            fd: os.FileHandle,
            iov: []os.linux.iovec,
            offset: usize,
            result: Error!usize,

            pub const Error = os.File.ReadError;
        };

        pub const OpenRead = struct {
            /// must be null terminated. TODO https://github.com/ziglang/zig/issues/265
            path: []const u8,
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

/// data - both the outer and inner references - must live until pwritev promise completes.
pub async fn pwritev(loop: *event.Loop, fd: os.FileHandle, offset: usize, data: []const []const u8) !void {
    //const data_dupe = try mem.dupe(loop.allocator, []const u8, data);
    //defer loop.allocator.free(data_dupe);

    // workaround for https://github.com/ziglang/zig/issues/1194
    var my_handle: promise = undefined;
    suspend |p| {
        my_handle = p;
        resume p;
    }

    var req_node = RequestNode{
        .next = undefined,
        .data = Request{
            .msg = Request.Msg{
                .PWriteV = Request.Msg.PWriteV{
                    .fd = fd,
                    .data = data,
                    .offset = offset,
                    .result = undefined,
                },
            },
            .finish = Request.Finish{
                .TickNode = event.Loop.NextTickNode{
                    .next = undefined,
                    .data = my_handle,
                },
            },
        },
    };

    suspend |_| {
        loop.linuxFsRequest(&req_node);
    }

    return req_node.data.msg.PWriteV.result;
}

/// data - just the inner references - must live until pwritev promise completes.
pub async fn preadv(loop: *event.Loop, fd: os.FileHandle, offset: usize, data: []const []u8) !usize {
    //const data_dupe = try mem.dupe(loop.allocator, []const u8, data);
    //defer loop.allocator.free(data_dupe);

    // workaround for https://github.com/ziglang/zig/issues/1194
    var my_handle: promise = undefined;
    suspend |p| {
        my_handle = p;
        resume p;
    }

    const iovecs = try loop.allocator.alloc(os.linux.iovec, data.len);
    defer loop.allocator.free(iovecs);

    for (data) |buf, i| {
        iovecs[i] = os.linux.iovec{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        };
    }

    var req_node = RequestNode{
        .next = undefined,
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
                .TickNode = event.Loop.NextTickNode{
                    .next = undefined,
                    .data = my_handle,
                },
            },
        },
    };

    suspend |_| {
        loop.linuxFsRequest(&req_node);
    }

    return req_node.data.msg.PReadV.result;
}

pub async fn openRead(loop: *event.Loop, path: []const u8) os.File.OpenError!os.FileHandle {
    // workaround for https://github.com/ziglang/zig/issues/1194
    var my_handle: promise = undefined;
    suspend |p| {
        my_handle = p;
        resume p;
    }

    var req_node = RequestNode{
        .next = undefined,
        .data = Request{
            .msg = Request.Msg{
                .OpenRead = Request.Msg.OpenRead{
                    .path = path,
                    .result = undefined,
                },
            },
            .finish = Request.Finish{
                .TickNode = event.Loop.NextTickNode{
                    .next = undefined,
                    .data = my_handle,
                },
            },
        },
    };

    suspend |_| {
        loop.linuxFsRequest(&req_node);
    }

    return req_node.data.msg.OpenRead.result;
}

/// This abstraction helps to close file handles in defer expressions
/// without suspending. Start a CloseOperation before opening a file.
pub const CloseOperation = struct {
    loop: *event.Loop,
    have_fd: bool,
    close_req_node: RequestNode,

    pub fn create(loop: *event.Loop) (error{OutOfMemory}!*CloseOperation) {
        const self = try loop.allocator.createOne(CloseOperation);
        self.* = CloseOperation{
            .loop = loop,
            .have_fd = false,
            .close_req_node = RequestNode{
                .next = undefined,
                .data = Request{
                    .msg = Request.Msg{
                        .Close = Request.Msg.Close{ .fd = undefined },
                    },
                    .finish = Request.Finish{ .DeallocCloseOperation = self },
                },
            },
        };
        return self;
    }

    /// Defer this after creating.
    pub fn deinit(self: *CloseOperation) void {
        if (self.have_fd) {
            self.loop.linuxFsRequest(&self.close_req_node);
        } else {
            self.loop.allocator.destroy(self);
        }
    }

    pub fn setHandle(self: *CloseOperation, handle: os.FileHandle) void {
        self.close_req_node.data.msg.Close.fd = handle;
        self.have_fd = true;
    }
};

/// contents must remain alive until writeFile completes.
pub async fn writeFile(loop: *event.Loop, path: []const u8, contents: []const u8) !void {
    return await (async writeFileMode(loop, path, contents, os.File.default_mode) catch unreachable);
}

/// contents must remain alive until writeFile completes.
pub async fn writeFileMode(loop: *event.Loop, path: []const u8, contents: []const u8, mode: os.File.Mode) !void {
    // workaround for https://github.com/ziglang/zig/issues/1194
    var my_handle: promise = undefined;
    suspend |p| {
        my_handle = p;
        resume p;
    }

    const path_with_null = try std.cstr.addNullByte(loop.allocator, path);
    defer loop.allocator.free(path_with_null);

    var req_node = RequestNode{
        .next = undefined,
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
                .TickNode = event.Loop.NextTickNode{
                    .next = undefined,
                    .data = my_handle,
                },
            },
        },
    };

    suspend |_| {
        loop.linuxFsRequest(&req_node);
    }

    return req_node.data.msg.WriteFile.result;
}

/// The promise resumes when the last data has been confirmed written, but before the file handle
/// is closed.
pub async fn readFile(loop: *event.Loop, file_path: []const u8, max_size: usize) ![]u8 {
    var close_op = try CloseOperation.create(loop);
    defer close_op.deinit();

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
        const amt = try await (async preadv(loop, fd, list.len, buf_array) catch unreachable);
        list.len += amt;
        if (amt < buf.len) {
            return list.toOwnedSlice();
        }
    }
}

const test_tmp_dir = "std_event_fs_test";

test "write a file, watch it, write it again" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const allocator = &da.allocator;

    // TODO move this into event loop too
    try os.makePath(allocator, test_tmp_dir);
    defer os.deleteTree(allocator, test_tmp_dir) catch {};

    var loop: event.Loop = undefined;
    try loop.initMultiThreaded(allocator);
    defer loop.deinit();

    var result: error!void = undefined;
    const handle = try async<allocator> testFsWatchCantFail(&loop, &result);
    defer cancel handle;

    loop.run();
    return result;
}

async fn testFsWatchCantFail(loop: *event.Loop, result: *(error!void)) void {
    result.* = await async testFsWatch(loop) catch unreachable;
}

async fn testFsWatch(loop: *event.Loop) !void {
    const file_path = try os.path.join(loop.allocator, test_tmp_dir, "file.txt");
    defer loop.allocator.free(file_path);

    const contents =
        \\line 1
        \\line 2
    ;

    // first just write then read the file
    try await try async writeFile(loop, file_path, contents);

    const read_contents = try await try async readFile(loop, file_path, 1024 * 1024);
    assert(mem.eql(u8, read_contents, contents));
}
