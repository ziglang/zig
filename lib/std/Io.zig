const builtin = @import("builtin");
const is_windows = builtin.os.tag == .windows;

const std = @import("std.zig");
const windows = std.os.windows;
const posix = std.posix;
const math = std.math;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

pub const Limit = enum(usize) {
    nothing = 0,
    unlimited = std.math.maxInt(usize),
    _,

    /// `std.math.maxInt(usize)` is interpreted to mean `.unlimited`.
    pub fn limited(n: usize) Limit {
        return @enumFromInt(n);
    }

    /// Any value grater than `std.math.maxInt(usize)` is interpreted to mean
    /// `.unlimited`.
    pub fn limited64(n: u64) Limit {
        return @enumFromInt(@min(n, std.math.maxInt(usize)));
    }

    pub fn countVec(data: []const []const u8) Limit {
        var total: usize = 0;
        for (data) |d| total += d.len;
        return .limited(total);
    }

    pub fn min(a: Limit, b: Limit) Limit {
        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn minInt(l: Limit, n: usize) usize {
        return @min(n, @intFromEnum(l));
    }

    pub fn minInt64(l: Limit, n: u64) usize {
        return @min(n, @intFromEnum(l));
    }

    pub fn slice(l: Limit, s: []u8) []u8 {
        return s[0..l.minInt(s.len)];
    }

    pub fn sliceConst(l: Limit, s: []const u8) []const u8 {
        return s[0..l.minInt(s.len)];
    }

    pub fn toInt(l: Limit) ?usize {
        return switch (l) {
            else => @intFromEnum(l),
            .unlimited => null,
        };
    }

    /// Reduces a slice to account for the limit, leaving room for one extra
    /// byte above the limit, allowing for the use case of differentiating
    /// between end-of-stream and reaching the limit.
    pub fn slice1(l: Limit, non_empty_buffer: []u8) []u8 {
        assert(non_empty_buffer.len >= 1);
        return non_empty_buffer[0..@min(@intFromEnum(l) +| 1, non_empty_buffer.len)];
    }

    pub fn nonzero(l: Limit) bool {
        return @intFromEnum(l) > 0;
    }

    /// Return a new limit reduced by `amount` or return `null` indicating
    /// limit would be exceeded.
    pub fn subtract(l: Limit, amount: usize) ?Limit {
        if (l == .unlimited) return .unlimited;
        if (amount > @intFromEnum(l)) return null;
        return @enumFromInt(@intFromEnum(l) - amount);
    }
};

pub const Reader = @import("Io/Reader.zig");
pub const Writer = @import("Io/Writer.zig");

pub const tty = @import("Io/tty.zig");

pub fn poll(
    gpa: Allocator,
    comptime StreamEnum: type,
    files: PollFiles(StreamEnum),
) Poller(StreamEnum) {
    const enum_fields = @typeInfo(StreamEnum).@"enum".fields;
    var result: Poller(StreamEnum) = .{
        .gpa = gpa,
        .readers = @splat(.failing),
        .poll_fds = undefined,
        .windows = if (is_windows) .{
            .first_read_done = false,
            .overlapped = [1]windows.OVERLAPPED{
                std.mem.zeroes(windows.OVERLAPPED),
            } ** enum_fields.len,
            .small_bufs = undefined,
            .active = .{
                .count = 0,
                .handles_buf = undefined,
                .stream_map = undefined,
            },
        } else {},
    };

    inline for (enum_fields, 0..) |field, i| {
        if (is_windows) {
            result.windows.active.handles_buf[i] = @field(files, field.name).handle;
        } else {
            result.poll_fds[i] = .{
                .fd = @field(files, field.name).handle,
                .events = posix.POLL.IN,
                .revents = undefined,
            };
        }
    }

    return result;
}

pub fn Poller(comptime StreamEnum: type) type {
    return struct {
        const enum_fields = @typeInfo(StreamEnum).@"enum".fields;
        const PollFd = if (is_windows) void else posix.pollfd;

        gpa: Allocator,
        readers: [enum_fields.len]Reader,
        poll_fds: [enum_fields.len]PollFd,
        windows: if (is_windows) struct {
            first_read_done: bool,
            overlapped: [enum_fields.len]windows.OVERLAPPED,
            small_bufs: [enum_fields.len][128]u8,
            active: struct {
                count: math.IntFittingRange(0, enum_fields.len),
                handles_buf: [enum_fields.len]windows.HANDLE,
                stream_map: [enum_fields.len]StreamEnum,

                pub fn removeAt(self: *@This(), index: u32) void {
                    assert(index < self.count);
                    for (index + 1..self.count) |i| {
                        self.handles_buf[i - 1] = self.handles_buf[i];
                        self.stream_map[i - 1] = self.stream_map[i];
                    }
                    self.count -= 1;
                }
            },
        } else void,

        const Self = @This();

        pub fn deinit(self: *Self) void {
            const gpa = self.gpa;
            if (is_windows) {
                // cancel any pending IO to prevent clobbering OVERLAPPED value
                for (self.windows.active.handles_buf[0..self.windows.active.count]) |h| {
                    _ = windows.kernel32.CancelIo(h);
                }
            }
            inline for (&self.readers) |*r| gpa.free(r.buffer);
            self.* = undefined;
        }

        pub fn poll(self: *Self) !bool {
            if (is_windows) {
                return pollWindows(self, null);
            } else {
                return pollPosix(self, null);
            }
        }

        pub fn pollTimeout(self: *Self, nanoseconds: u64) !bool {
            if (is_windows) {
                return pollWindows(self, nanoseconds);
            } else {
                return pollPosix(self, nanoseconds);
            }
        }

        pub fn reader(self: *Self, which: StreamEnum) *Reader {
            return &self.readers[@intFromEnum(which)];
        }

        pub fn toOwnedSlice(self: *Self, which: StreamEnum) error{OutOfMemory}![]u8 {
            const gpa = self.gpa;
            const r = reader(self, which);
            if (r.seek == 0) {
                const new = try gpa.realloc(r.buffer, r.end);
                r.buffer = &.{};
                r.end = 0;
                return new;
            }
            const new = try gpa.dupe(u8, r.buffered());
            gpa.free(r.buffer);
            r.buffer = &.{};
            r.seek = 0;
            r.end = 0;
            return new;
        }

        fn pollWindows(self: *Self, nanoseconds: ?u64) !bool {
            const bump_amt = 512;
            const gpa = self.gpa;

            if (!self.windows.first_read_done) {
                var already_read_data = false;
                for (0..enum_fields.len) |i| {
                    const handle = self.windows.active.handles_buf[i];
                    switch (try windowsAsyncReadToFifoAndQueueSmallRead(
                        gpa,
                        handle,
                        &self.windows.overlapped[i],
                        &self.readers[i],
                        &self.windows.small_bufs[i],
                        bump_amt,
                    )) {
                        .populated, .empty => |state| {
                            if (state == .populated) already_read_data = true;
                            self.windows.active.handles_buf[self.windows.active.count] = handle;
                            self.windows.active.stream_map[self.windows.active.count] = @as(StreamEnum, @enumFromInt(i));
                            self.windows.active.count += 1;
                        },
                        .closed => {}, // don't add to the wait_objects list
                        .closed_populated => {
                            // don't add to the wait_objects list, but we did already get data
                            already_read_data = true;
                        },
                    }
                }
                self.windows.first_read_done = true;
                if (already_read_data) return true;
            }

            while (true) {
                if (self.windows.active.count == 0) return false;

                const status = windows.kernel32.WaitForMultipleObjects(
                    self.windows.active.count,
                    &self.windows.active.handles_buf,
                    0,
                    if (nanoseconds) |ns|
                        @min(std.math.cast(u32, ns / std.time.ns_per_ms) orelse (windows.INFINITE - 1), windows.INFINITE - 1)
                    else
                        windows.INFINITE,
                );
                if (status == windows.WAIT_FAILED)
                    return windows.unexpectedError(windows.GetLastError());
                if (status == windows.WAIT_TIMEOUT)
                    return true;

                if (status < windows.WAIT_OBJECT_0 or status > windows.WAIT_OBJECT_0 + enum_fields.len - 1)
                    unreachable;

                const active_idx = status - windows.WAIT_OBJECT_0;

                const stream_idx = @intFromEnum(self.windows.active.stream_map[active_idx]);
                const handle = self.windows.active.handles_buf[active_idx];

                const overlapped = &self.windows.overlapped[stream_idx];
                const stream_reader = &self.readers[stream_idx];
                const small_buf = &self.windows.small_bufs[stream_idx];

                const num_bytes_read = switch (try windowsGetReadResult(handle, overlapped, false)) {
                    .success => |n| n,
                    .closed => {
                        self.windows.active.removeAt(active_idx);
                        continue;
                    },
                    .aborted => unreachable,
                };
                const buf = small_buf[0..num_bytes_read];
                const dest = try writableSliceGreedyAlloc(stream_reader, gpa, buf.len);
                @memcpy(dest[0..buf.len], buf);
                advanceBufferEnd(stream_reader, buf.len);

                switch (try windowsAsyncReadToFifoAndQueueSmallRead(
                    gpa,
                    handle,
                    overlapped,
                    stream_reader,
                    small_buf,
                    bump_amt,
                )) {
                    .empty => {}, // irrelevant, we already got data from the small buffer
                    .populated => {},
                    .closed,
                    .closed_populated, // identical, since we already got data from the small buffer
                    => self.windows.active.removeAt(active_idx),
                }
                return true;
            }
        }

        fn pollPosix(self: *Self, nanoseconds: ?u64) !bool {
            const gpa = self.gpa;
            // We ask for ensureUnusedCapacity with this much extra space. This
            // has more of an effect on small reads because once the reads
            // start to get larger the amount of space an ArrayList will
            // allocate grows exponentially.
            const bump_amt = 512;

            const err_mask = posix.POLL.ERR | posix.POLL.NVAL | posix.POLL.HUP;

            const events_len = try posix.poll(&self.poll_fds, if (nanoseconds) |ns|
                std.math.cast(i32, ns / std.time.ns_per_ms) orelse std.math.maxInt(i32)
            else
                -1);
            if (events_len == 0) {
                for (self.poll_fds) |poll_fd| {
                    if (poll_fd.fd != -1) return true;
                } else return false;
            }

            var keep_polling = false;
            for (&self.poll_fds, &self.readers) |*poll_fd, *r| {
                // Try reading whatever is available before checking the error
                // conditions.
                // It's still possible to read after a POLL.HUP is received,
                // always check if there's some data waiting to be read first.
                if (poll_fd.revents & posix.POLL.IN != 0) {
                    const buf = try writableSliceGreedyAlloc(r, gpa, bump_amt);
                    const amt = posix.read(poll_fd.fd, buf) catch |err| switch (err) {
                        error.BrokenPipe => 0, // Handle the same as EOF.
                        else => |e| return e,
                    };
                    advanceBufferEnd(r, amt);
                    if (amt == 0) {
                        // Remove the fd when the EOF condition is met.
                        poll_fd.fd = -1;
                    } else {
                        keep_polling = true;
                    }
                } else if (poll_fd.revents & err_mask != 0) {
                    // Exclude the fds that signaled an error.
                    poll_fd.fd = -1;
                } else if (poll_fd.fd != -1) {
                    keep_polling = true;
                }
            }
            return keep_polling;
        }

        /// Returns a slice into the unused capacity of `buffer` with at least
        /// `min_len` bytes, extending `buffer` by resizing it with `gpa` as necessary.
        ///
        /// After calling this function, typically the caller will follow up with a
        /// call to `advanceBufferEnd` to report the actual number of bytes buffered.
        fn writableSliceGreedyAlloc(r: *Reader, allocator: Allocator, min_len: usize) Allocator.Error![]u8 {
            {
                const unused = r.buffer[r.end..];
                if (unused.len >= min_len) return unused;
            }
            if (r.seek > 0) {
                const data = r.buffer[r.seek..r.end];
                @memmove(r.buffer[0..data.len], data);
                r.seek = 0;
                r.end = data.len;
            }
            {
                var list: std.ArrayList(u8) = .{
                    .items = r.buffer[0..r.end],
                    .capacity = r.buffer.len,
                };
                defer r.buffer = list.allocatedSlice();
                try list.ensureUnusedCapacity(allocator, min_len);
            }
            const unused = r.buffer[r.end..];
            assert(unused.len >= min_len);
            return unused;
        }

        /// After writing directly into the unused capacity of `buffer`, this function
        /// updates `end` so that users of `Reader` can receive the data.
        fn advanceBufferEnd(r: *Reader, n: usize) void {
            assert(n <= r.buffer.len - r.end);
            r.end += n;
        }

        /// The `ReadFile` docuementation states that `lpNumberOfBytesRead` does not have a meaningful
        /// result when using overlapped I/O, but also that it cannot be `null` on Windows 7. For
        /// compatibility, we point it to this dummy variables, which we never otherwise access.
        /// See: https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-readfile
        var win_dummy_bytes_read: u32 = undefined;

        /// Read as much data as possible from `handle` with `overlapped`, and write it to the FIFO. Before
        /// returning, queue a read into `small_buf` so that `WaitForMultipleObjects` returns when more data
        /// is available. `handle` must have no pending asynchronous operation.
        fn windowsAsyncReadToFifoAndQueueSmallRead(
            gpa: Allocator,
            handle: windows.HANDLE,
            overlapped: *windows.OVERLAPPED,
            r: *Reader,
            small_buf: *[128]u8,
            bump_amt: usize,
        ) !enum { empty, populated, closed_populated, closed } {
            var read_any_data = false;
            while (true) {
                const fifo_read_pending = while (true) {
                    const buf = try writableSliceGreedyAlloc(r, gpa, bump_amt);
                    const buf_len = math.cast(u32, buf.len) orelse math.maxInt(u32);

                    if (0 == windows.kernel32.ReadFile(
                        handle,
                        buf.ptr,
                        buf_len,
                        &win_dummy_bytes_read,
                        overlapped,
                    )) switch (windows.GetLastError()) {
                        .IO_PENDING => break true,
                        .BROKEN_PIPE => return if (read_any_data) .closed_populated else .closed,
                        else => |err| return windows.unexpectedError(err),
                    };

                    const num_bytes_read = switch (try windowsGetReadResult(handle, overlapped, false)) {
                        .success => |n| n,
                        .closed => return if (read_any_data) .closed_populated else .closed,
                        .aborted => unreachable,
                    };

                    read_any_data = true;
                    advanceBufferEnd(r, num_bytes_read);

                    if (num_bytes_read == buf_len) {
                        // We filled the buffer, so there's probably more data available.
                        continue;
                    } else {
                        // We didn't fill the buffer, so assume we're out of data.
                        // There is no pending read.
                        break false;
                    }
                };

                if (fifo_read_pending) cancel_read: {
                    // Cancel the pending read into the FIFO.
                    _ = windows.kernel32.CancelIo(handle);

                    // We have to wait for the handle to be signalled, i.e. for the cancellation to complete.
                    switch (windows.kernel32.WaitForSingleObject(handle, windows.INFINITE)) {
                        windows.WAIT_OBJECT_0 => {},
                        windows.WAIT_FAILED => return windows.unexpectedError(windows.GetLastError()),
                        else => unreachable,
                    }

                    // If it completed before we canceled, make sure to tell the FIFO!
                    const num_bytes_read = switch (try windowsGetReadResult(handle, overlapped, true)) {
                        .success => |n| n,
                        .closed => return if (read_any_data) .closed_populated else .closed,
                        .aborted => break :cancel_read,
                    };
                    read_any_data = true;
                    advanceBufferEnd(r, num_bytes_read);
                }

                // Try to queue the 1-byte read.
                if (0 == windows.kernel32.ReadFile(
                    handle,
                    small_buf,
                    small_buf.len,
                    &win_dummy_bytes_read,
                    overlapped,
                )) switch (windows.GetLastError()) {
                    .IO_PENDING => {
                        // 1-byte read pending as intended
                        return if (read_any_data) .populated else .empty;
                    },
                    .BROKEN_PIPE => return if (read_any_data) .closed_populated else .closed,
                    else => |err| return windows.unexpectedError(err),
                };

                // We got data back this time. Write it to the FIFO and run the main loop again.
                const num_bytes_read = switch (try windowsGetReadResult(handle, overlapped, false)) {
                    .success => |n| n,
                    .closed => return if (read_any_data) .closed_populated else .closed,
                    .aborted => unreachable,
                };
                const buf = small_buf[0..num_bytes_read];
                const dest = try writableSliceGreedyAlloc(r, gpa, buf.len);
                @memcpy(dest[0..buf.len], buf);
                advanceBufferEnd(r, buf.len);
                read_any_data = true;
            }
        }

        /// Simple wrapper around `GetOverlappedResult` to determine the result of a `ReadFile` operation.
        /// If `!allow_aborted`, then `aborted` is never returned (`OPERATION_ABORTED` is considered unexpected).
        ///
        /// The `ReadFile` documentation states that the number of bytes read by an overlapped `ReadFile` must be determined using `GetOverlappedResult`, even if the
        /// operation immediately returns data:
        /// "Use NULL for [lpNumberOfBytesRead] if this is an asynchronous operation to avoid potentially
        /// erroneous results."
        /// "If `hFile` was opened with `FILE_FLAG_OVERLAPPED`, the following conditions are in effect: [...]
        /// The lpNumberOfBytesRead parameter should be set to NULL. Use the GetOverlappedResult function to
        /// get the actual number of bytes read."
        /// See: https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-readfile
        fn windowsGetReadResult(
            handle: windows.HANDLE,
            overlapped: *windows.OVERLAPPED,
            allow_aborted: bool,
        ) !union(enum) {
            success: u32,
            closed,
            aborted,
        } {
            var num_bytes_read: u32 = undefined;
            if (0 == windows.kernel32.GetOverlappedResult(
                handle,
                overlapped,
                &num_bytes_read,
                0,
            )) switch (windows.GetLastError()) {
                .BROKEN_PIPE => return .closed,
                .OPERATION_ABORTED => |err| if (allow_aborted) {
                    return .aborted;
                } else {
                    return windows.unexpectedError(err);
                },
                else => |err| return windows.unexpectedError(err),
            };
            return .{ .success = num_bytes_read };
        }
    };
}

/// Given an enum, returns a struct with fields of that enum, each field
/// representing an I/O stream for polling.
pub fn PollFiles(comptime StreamEnum: type) type {
    const enum_fields = @typeInfo(StreamEnum).@"enum".fields;
    var struct_fields: [enum_fields.len]std.builtin.Type.StructField = undefined;
    for (&struct_fields, enum_fields) |*struct_field, enum_field| {
        struct_field.* = .{
            .name = enum_field.name,
            .type = std.fs.File,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(std.fs.File),
        };
    }
    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &struct_fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}

test {
    _ = net;
    _ = Reader;
    _ = Writer;
    _ = tty;
    _ = Evented;
    _ = Threaded;
    _ = @import("Io/test.zig");
}

const Io = @This();

pub const Evented = switch (builtin.os.tag) {
    .linux => switch (builtin.cpu.arch) {
        .x86_64, .aarch64 => @import("Io/IoUring.zig"),
        else => void, // context-switching code not implemented yet
    },
    .dragonfly, .freebsd, .netbsd, .openbsd, .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => switch (builtin.cpu.arch) {
        .x86_64, .aarch64 => @import("Io/Kqueue.zig"),
        else => void, // context-switching code not implemented yet
    },
    else => void,
};
pub const Threaded = @import("Io/Threaded.zig");
pub const net = @import("Io/net.zig");

userdata: ?*anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// If it returns `null` it means `result` has been already populated and
    /// `await` will be a no-op.
    ///
    /// When this function returns non-null, the implementation guarantees that
    /// a unit of concurrency has been assigned to the returned task.
    ///
    /// Thread-safe.
    async: *const fn (
        /// Corresponds to `Io.userdata`.
        userdata: ?*anyopaque,
        /// The pointer of this slice is an "eager" result value.
        /// The length is the size in bytes of the result type.
        /// This pointer's lifetime expires directly after the call to this function.
        result: []u8,
        result_alignment: std.mem.Alignment,
        /// Copied and then passed to `start`.
        context: []const u8,
        context_alignment: std.mem.Alignment,
        start: *const fn (context: *const anyopaque, result: *anyopaque) void,
    ) ?*AnyFuture,
    /// Thread-safe.
    concurrent: *const fn (
        /// Corresponds to `Io.userdata`.
        userdata: ?*anyopaque,
        result_len: usize,
        result_alignment: std.mem.Alignment,
        /// Copied and then passed to `start`.
        context: []const u8,
        context_alignment: std.mem.Alignment,
        start: *const fn (context: *const anyopaque, result: *anyopaque) void,
    ) ConcurrentError!*AnyFuture,
    /// This function is only called when `async` returns a non-null value.
    ///
    /// Thread-safe.
    await: *const fn (
        /// Corresponds to `Io.userdata`.
        userdata: ?*anyopaque,
        /// The same value that was returned from `async`.
        any_future: *AnyFuture,
        /// Points to a buffer where the result is written.
        /// The length is equal to size in bytes of result type.
        result: []u8,
        result_alignment: std.mem.Alignment,
    ) void,
    /// Equivalent to `await` but initiates cancel request.
    ///
    /// This function is only called when `async` returns a non-null value.
    ///
    /// Thread-safe.
    cancel: *const fn (
        /// Corresponds to `Io.userdata`.
        userdata: ?*anyopaque,
        /// The same value that was returned from `async`.
        any_future: *AnyFuture,
        /// Points to a buffer where the result is written.
        /// The length is equal to size in bytes of result type.
        result: []u8,
        result_alignment: std.mem.Alignment,
    ) void,
    /// Returns whether the current thread of execution is known to have
    /// been requested to cancel.
    ///
    /// Thread-safe.
    cancelRequested: *const fn (?*anyopaque) bool,

    /// Executes `start` asynchronously in a manner such that it cleans itself
    /// up. This mode does not support results, await, or cancel.
    ///
    /// Thread-safe.
    groupAsync: *const fn (
        /// Corresponds to `Io.userdata`.
        userdata: ?*anyopaque,
        /// Owner of the spawned async task.
        group: *Group,
        /// Copied and then passed to `start`.
        context: []const u8,
        context_alignment: std.mem.Alignment,
        start: *const fn (*Group, context: *const anyopaque) void,
    ) void,
    groupWait: *const fn (?*anyopaque, *Group, token: *anyopaque) void,
    groupCancel: *const fn (?*anyopaque, *Group, token: *anyopaque) void,

    /// Blocks until one of the futures from the list has a result ready, such
    /// that awaiting it will not block. Returns that index.
    select: *const fn (?*anyopaque, futures: []const *AnyFuture) Cancelable!usize,

    mutexLock: *const fn (?*anyopaque, prev_state: Mutex.State, mutex: *Mutex) Cancelable!void,
    mutexLockUncancelable: *const fn (?*anyopaque, prev_state: Mutex.State, mutex: *Mutex) void,
    mutexUnlock: *const fn (?*anyopaque, prev_state: Mutex.State, mutex: *Mutex) void,

    conditionWait: *const fn (?*anyopaque, cond: *Condition, mutex: *Mutex) Cancelable!void,
    conditionWaitUncancelable: *const fn (?*anyopaque, cond: *Condition, mutex: *Mutex) void,
    conditionWake: *const fn (?*anyopaque, cond: *Condition, wake: Condition.Wake) void,

    dirMake: *const fn (?*anyopaque, Dir, sub_path: []const u8, Dir.Mode) Dir.MakeError!void,
    dirMakePath: *const fn (?*anyopaque, Dir, sub_path: []const u8, Dir.Mode) Dir.MakeError!void,
    dirMakeOpenPath: *const fn (?*anyopaque, Dir, sub_path: []const u8, Dir.OpenOptions) Dir.MakeOpenPathError!Dir,
    dirStat: *const fn (?*anyopaque, Dir) Dir.StatError!Dir.Stat,
    dirStatPath: *const fn (?*anyopaque, Dir, sub_path: []const u8, Dir.StatPathOptions) Dir.StatPathError!File.Stat,
    dirAccess: *const fn (?*anyopaque, Dir, sub_path: []const u8, Dir.AccessOptions) Dir.AccessError!void,
    dirCreateFile: *const fn (?*anyopaque, Dir, sub_path: []const u8, File.CreateFlags) File.OpenError!File,
    dirOpenFile: *const fn (?*anyopaque, Dir, sub_path: []const u8, File.OpenFlags) File.OpenError!File,
    dirOpenDir: *const fn (?*anyopaque, Dir, sub_path: []const u8, Dir.OpenOptions) Dir.OpenError!Dir,
    dirClose: *const fn (?*anyopaque, Dir) void,
    fileStat: *const fn (?*anyopaque, File) File.StatError!File.Stat,
    fileClose: *const fn (?*anyopaque, File) void,
    fileWriteStreaming: *const fn (?*anyopaque, File, buffer: [][]const u8) File.WriteStreamingError!usize,
    fileWritePositional: *const fn (?*anyopaque, File, buffer: [][]const u8, offset: u64) File.WritePositionalError!usize,
    /// Returns 0 on end of stream.
    fileReadStreaming: *const fn (?*anyopaque, File, data: [][]u8) File.Reader.Error!usize,
    /// Returns 0 on end of stream.
    fileReadPositional: *const fn (?*anyopaque, File, data: [][]u8, offset: u64) File.ReadPositionalError!usize,
    fileSeekBy: *const fn (?*anyopaque, File, relative_offset: i64) File.SeekError!void,
    fileSeekTo: *const fn (?*anyopaque, File, absolute_offset: u64) File.SeekError!void,
    openSelfExe: *const fn (?*anyopaque, File.OpenFlags) File.OpenSelfExeError!File,

    now: *const fn (?*anyopaque, Clock) Clock.Error!Timestamp,
    sleep: *const fn (?*anyopaque, Timeout) SleepError!void,

    netListenIp: *const fn (?*anyopaque, address: net.IpAddress, net.IpAddress.ListenOptions) net.IpAddress.ListenError!net.Server,
    netAccept: *const fn (?*anyopaque, server: net.Socket.Handle) net.Server.AcceptError!net.Stream,
    netBindIp: *const fn (?*anyopaque, address: *const net.IpAddress, options: net.IpAddress.BindOptions) net.IpAddress.BindError!net.Socket,
    netConnectIp: *const fn (?*anyopaque, address: *const net.IpAddress, options: net.IpAddress.ConnectOptions) net.IpAddress.ConnectError!net.Stream,
    netListenUnix: *const fn (?*anyopaque, *const net.UnixAddress, net.UnixAddress.ListenOptions) net.UnixAddress.ListenError!net.Socket.Handle,
    netConnectUnix: *const fn (?*anyopaque, *const net.UnixAddress) net.UnixAddress.ConnectError!net.Socket.Handle,
    netSend: *const fn (?*anyopaque, net.Socket.Handle, []net.OutgoingMessage, net.SendFlags) struct { ?net.Socket.SendError, usize },
    netReceive: *const fn (?*anyopaque, net.Socket.Handle, message_buffer: []net.IncomingMessage, data_buffer: []u8, net.ReceiveFlags, Timeout) struct { ?net.Socket.ReceiveTimeoutError, usize },
    /// Returns 0 on end of stream.
    netRead: *const fn (?*anyopaque, src: net.Socket.Handle, data: [][]u8) net.Stream.Reader.Error!usize,
    netWrite: *const fn (?*anyopaque, dest: net.Socket.Handle, header: []const u8, data: []const []const u8, splat: usize) net.Stream.Writer.Error!usize,
    netClose: *const fn (?*anyopaque, handle: net.Socket.Handle) void,
    netInterfaceNameResolve: *const fn (?*anyopaque, *const net.Interface.Name) net.Interface.Name.ResolveError!net.Interface,
    netInterfaceName: *const fn (?*anyopaque, net.Interface) net.Interface.NameError!net.Interface.Name,
    netLookup: *const fn (?*anyopaque, net.HostName, *Queue(net.HostName.LookupResult), net.HostName.LookupOptions) void,
};

pub const Cancelable = error{
    /// Caller has requested the async operation to stop.
    Canceled,
};

pub const UnexpectedError = error{
    /// The Operating System returned an undocumented error code.
    ///
    /// This error is in theory not possible, but it would be better
    /// to handle this error than to invoke undefined behavior.
    ///
    /// When this error code is observed, it usually means the Zig Standard
    /// Library needs a small patch to add the error code to the error set for
    /// the respective function.
    Unexpected,
};

pub const Dir = @import("Io/Dir.zig");
pub const File = @import("Io/File.zig");

pub const Clock = enum {
    /// A settable system-wide clock that measures real (i.e. wall-clock)
    /// time. This clock is affected by discontinuous jumps in the system
    /// time (e.g., if the system administrator manually changes the
    /// clock), and by frequency adjustments performed by NTP and similar
    /// applications.
    ///
    /// This clock normally counts the number of seconds since 1970-01-01
    /// 00:00:00 Coordinated Universal Time (UTC) except that it ignores
    /// leap seconds; near a leap second it is typically adjusted by NTP to
    /// stay roughly in sync with UTC.
    ///
    /// Timestamps returned by implementations of this clock represent time
    /// elapsed since 1970-01-01T00:00:00Z, the POSIX/Unix epoch, ignoring
    /// leap seconds. This is colloquially known as "Unix time". If the
    /// underlying OS uses a different epoch for native timestamps (e.g.,
    /// Windows, which uses 1601-01-01) they are translated accordingly.
    real,
    /// A nonsettable system-wide clock that represents time since some
    /// unspecified point in the past.
    ///
    /// Monotonic: Guarantees that the time returned by consecutive calls
    /// will not go backwards, but successive calls may return identical
    /// (not-increased) time values.
    ///
    /// Not affected by discontinuous jumps in the system time (e.g., if
    /// the system administrator manually changes the clock), but may be
    /// affected by frequency adjustments.
    ///
    /// This clock expresses intent to **exclude time that the system is
    /// suspended**. However, implementations may be unable to satisify
    /// this, and may include that time.
    ///
    /// * On Linux, corresponds `CLOCK_MONOTONIC`.
    /// * On macOS, corresponds to `CLOCK_UPTIME_RAW`.
    awake,
    /// Identical to `awake` except it expresses intent to **include time
    /// that the system is suspended**, however, due to limitations it may
    /// behave identically to `awake`.
    ///
    /// * On Linux, corresponds `CLOCK_BOOTTIME`.
    /// * On macOS, corresponds to `CLOCK_MONOTONIC_RAW`.
    boot,
    /// Tracks the amount of CPU in user or kernel mode used by the calling
    /// process.
    cpu_process,
    /// Tracks the amount of CPU in user or kernel mode used by the calling
    /// thread.
    cpu_thread,

    pub const Error = error{UnsupportedClock} || UnexpectedError;

    /// This function is not cancelable because first of all it does not block,
    /// but more importantly, the cancelation logic itself may want to check
    /// the time.
    pub fn now(clock: Clock, io: Io) Error!Io.Timestamp {
        return io.vtable.now(io.userdata, clock);
    }

    pub const Timestamp = struct {
        raw: Io.Timestamp,
        clock: Clock,

        /// This function is not cancelable because first of all it does not block,
        /// but more importantly, the cancelation logic itself may want to check
        /// the time.
        pub fn now(io: Io, clock: Clock) Error!Clock.Timestamp {
            return .{
                .raw = try io.vtable.now(io.userdata, clock),
                .clock = clock,
            };
        }

        pub fn wait(t: Clock.Timestamp, io: Io) SleepError!void {
            return io.vtable.sleep(io.userdata, .{ .deadline = t });
        }

        pub fn durationTo(from: Clock.Timestamp, to: Clock.Timestamp) Clock.Duration {
            assert(from.clock == to.clock);
            return .{
                .raw = from.raw.durationTo(to.raw),
                .clock = from.clock,
            };
        }

        pub fn addDuration(from: Clock.Timestamp, duration: Clock.Duration) Clock.Timestamp {
            assert(from.clock == duration.clock);
            return .{
                .raw = from.raw.addDuration(duration.raw),
                .clock = from.clock,
            };
        }

        pub fn subDuration(from: Clock.Timestamp, duration: Clock.Duration) Clock.Timestamp {
            assert(from.clock == duration.clock);
            return .{
                .raw = from.raw.subDuration(duration.raw),
                .clock = from.clock,
            };
        }

        pub fn fromNow(io: Io, duration: Clock.Duration) Error!Clock.Timestamp {
            return .{
                .clock = duration.clock,
                .raw = (try duration.clock.now(io)).addDuration(duration.raw),
            };
        }

        pub fn untilNow(timestamp: Clock.Timestamp, io: Io) Error!Clock.Duration {
            const now_ts = try Clock.Timestamp.now(io, timestamp.clock);
            return timestamp.durationTo(now_ts);
        }

        pub fn durationFromNow(timestamp: Clock.Timestamp, io: Io) Error!Clock.Duration {
            const now_ts = try timestamp.clock.now(io);
            return .{
                .clock = timestamp.clock,
                .raw = now_ts.durationTo(timestamp.raw),
            };
        }

        pub fn toClock(t: Clock.Timestamp, io: Io, clock: Clock) Error!Clock.Timestamp {
            if (t.clock == clock) return t;
            const now_old = try t.clock.now(io);
            const now_new = try clock.now(io);
            const duration = now_old.durationTo(t);
            return .{
                .clock = clock,
                .raw = now_new.addDuration(duration),
            };
        }

        pub fn compare(lhs: Clock.Timestamp, op: std.math.CompareOperator, rhs: Clock.Timestamp) bool {
            assert(lhs.clock == rhs.clock);
            return std.math.compare(lhs.raw.nanoseconds, op, rhs.raw.nanoseconds);
        }
    };

    pub const Duration = struct {
        raw: Io.Duration,
        clock: Clock,

        pub fn sleep(duration: Clock.Duration, io: Io) SleepError!void {
            return io.vtable.sleep(io.userdata, .{ .duration = duration });
        }
    };
};

pub const Timestamp = struct {
    nanoseconds: i96,

    pub const zero: Timestamp = .{ .nanoseconds = 0 };

    pub fn durationTo(from: Timestamp, to: Timestamp) Duration {
        return .{ .nanoseconds = to.nanoseconds - from.nanoseconds };
    }

    pub fn addDuration(from: Timestamp, duration: Duration) Timestamp {
        return .{ .nanoseconds = from.nanoseconds + duration.nanoseconds };
    }

    pub fn subDuration(from: Timestamp, duration: Duration) Timestamp {
        return .{ .nanoseconds = from.nanoseconds - duration.nanoseconds };
    }

    pub fn withClock(t: Timestamp, clock: Clock) Clock.Timestamp {
        return .{ .nanoseconds = t.nanoseconds, .clock = clock };
    }

    pub fn fromNanoseconds(x: i96) Timestamp {
        return .{ .nanoseconds = x };
    }

    pub fn toMilliseconds(t: Timestamp) i64 {
        return @intCast(@divTrunc(t.nanoseconds, std.time.ns_per_ms));
    }

    pub fn toSeconds(t: Timestamp) i64 {
        return @intCast(@divTrunc(t.nanoseconds, std.time.ns_per_s));
    }

    pub fn toNanoseconds(t: Timestamp) i96 {
        return t.nanoseconds;
    }

    pub fn formatNumber(t: Timestamp, w: *std.Io.Writer, n: std.fmt.Number) std.Io.Writer.Error!void {
        return w.printInt(t.nanoseconds, n.mode.base() orelse 10, n.case, .{
            .precision = n.precision,
            .width = n.width,
            .alignment = n.alignment,
            .fill = n.fill,
        });
    }
};

pub const Duration = struct {
    nanoseconds: i96,

    pub const zero: Duration = .{ .nanoseconds = 0 };
    pub const max: Duration = .{ .nanoseconds = std.math.maxInt(i96) };

    pub fn fromNanoseconds(x: i96) Duration {
        return .{ .nanoseconds = x };
    }

    pub fn fromMilliseconds(x: i64) Duration {
        return .{ .nanoseconds = @as(i96, x) * std.time.ns_per_ms };
    }

    pub fn fromSeconds(x: i64) Duration {
        return .{ .nanoseconds = @as(i96, x) * std.time.ns_per_s };
    }

    pub fn toMilliseconds(d: Duration) i64 {
        return @intCast(@divTrunc(d.nanoseconds, std.time.ns_per_ms));
    }

    pub fn toSeconds(d: Duration) i64 {
        return @intCast(@divTrunc(d.nanoseconds, std.time.ns_per_s));
    }

    pub fn toNanoseconds(d: Duration) i96 {
        return d.nanoseconds;
    }
};

/// Declares under what conditions an operation should return `error.Timeout`.
pub const Timeout = union(enum) {
    none,
    duration: Clock.Duration,
    deadline: Clock.Timestamp,

    pub const Error = error{ Timeout, UnsupportedClock };

    pub fn toDeadline(t: Timeout, io: Io) Clock.Error!?Clock.Timestamp {
        return switch (t) {
            .none => null,
            .duration => |d| try .fromNow(io, d),
            .deadline => |d| d,
        };
    }

    pub fn toDurationFromNow(t: Timeout, io: Io) Clock.Error!?Clock.Duration {
        return switch (t) {
            .none => null,
            .duration => |d| d,
            .deadline => |d| try d.durationFromNow(io),
        };
    }

    pub fn sleep(timeout: Timeout, io: Io) SleepError!void {
        return io.vtable.sleep(io.userdata, timeout);
    }
};

pub const AnyFuture = opaque {};

pub fn Future(Result: type) type {
    return struct {
        any_future: ?*AnyFuture,
        result: Result,

        /// Equivalent to `await` but places a cancellation request.
        ///
        /// Idempotent. Not threadsafe.
        pub fn cancel(f: *@This(), io: Io) Result {
            const any_future = f.any_future orelse return f.result;
            io.vtable.cancel(io.userdata, any_future, @ptrCast(&f.result), .of(Result));
            f.any_future = null;
            return f.result;
        }

        /// Idempotent. Not threadsafe.
        pub fn await(f: *@This(), io: Io) Result {
            const any_future = f.any_future orelse return f.result;
            io.vtable.await(io.userdata, any_future, @ptrCast(&f.result), .of(Result));
            f.any_future = null;
            return f.result;
        }
    };
}

pub const Group = struct {
    state: usize,
    context: ?*anyopaque,
    token: ?*anyopaque,

    pub const init: Group = .{ .state = 0, .context = null, .token = null };

    /// Calls `function` with `args` asynchronously. The resource spawned is
    /// owned by the group.
    ///
    /// `function` *may* be called immediately, before `async` returns.
    ///
    /// When this function returns, it is guaranteed that `function` has
    /// already been called and completed, or it has successfully been assigned
    /// a unit of concurrency.
    ///
    /// After this is called, `wait` or `cancel` must be called before the
    /// group is deinitialized.
    ///
    /// Threadsafe.
    ///
    /// See also:
    /// * `Io.async`
    /// * `concurrent`
    pub fn async(g: *Group, io: Io, function: anytype, args: std.meta.ArgsTuple(@TypeOf(function))) void {
        const Args = @TypeOf(args);
        const TypeErased = struct {
            fn start(group: *Group, context: *const anyopaque) void {
                _ = group;
                const args_casted: *const Args = @ptrCast(@alignCast(context));
                @call(.auto, function, args_casted.*);
            }
        };
        io.vtable.groupAsync(io.userdata, g, @ptrCast(&args), .of(Args), TypeErased.start);
    }

    /// Blocks until all tasks of the group finish. During this time,
    /// cancellation requests propagate to all members of the group.
    ///
    /// Idempotent. Not threadsafe.
    pub fn wait(g: *Group, io: Io) void {
        const token = g.token orelse return;
        g.token = null;
        io.vtable.groupWait(io.userdata, g, token);
    }

    /// Equivalent to `wait` but immediately requests cancellation on all
    /// members of the group.
    ///
    /// Idempotent. Not threadsafe.
    pub fn cancel(g: *Group, io: Io) void {
        const token = g.token orelse return;
        g.token = null;
        io.vtable.groupCancel(io.userdata, g, token);
    }
};

pub fn Select(comptime U: type) type {
    return struct {
        io: Io,
        group: Group,
        queue: Queue(U),
        outstanding: usize,

        const S = @This();

        pub const Union = U;

        pub const Field = std.meta.FieldEnum(U);

        pub fn init(io: Io, buffer: []U) S {
            return .{
                .io = io,
                .queue = .init(buffer),
                .group = .init,
                .outstanding = 0,
            };
        }

        /// Calls `function` with `args` asynchronously. The resource spawned is
        /// owned by the select.
        ///
        /// `function` must have return type matching the `field` field of `Union`.
        ///
        /// `function` *may* be called immediately, before `async` returns.
        ///
        /// When this function returns, it is guaranteed that `function` has
        /// already been called and completed, or it has successfully been
        /// assigned a unit of concurrency.
        ///
        /// After this is called, `wait` or `cancel` must be called before the
        /// select is deinitialized.
        ///
        /// Threadsafe.
        ///
        /// Related:
        /// * `Io.async`
        /// * `Group.async`
        pub fn async(
            s: *S,
            comptime field: Field,
            function: anytype,
            args: std.meta.ArgsTuple(@TypeOf(function)),
        ) void {
            const Args = @TypeOf(args);
            const TypeErased = struct {
                fn start(group: *Group, context: *const anyopaque) void {
                    const args_casted: *const Args = @ptrCast(@alignCast(context));
                    const unerased_select: *S = @fieldParentPtr("group", group);
                    const elem = @unionInit(U, @tagName(field), @call(.auto, function, args_casted.*));
                    unerased_select.queue.putOneUncancelable(unerased_select.io, elem);
                }
            };
            _ = @atomicRmw(usize, &s.outstanding, .Add, 1, .monotonic);
            s.io.vtable.groupAsync(s.io.userdata, &s.group, @ptrCast(&args), .of(Args), TypeErased.start);
        }

        /// Blocks until another task of the select finishes.
        ///
        /// Asserts there is at least one more `outstanding` task.
        ///
        /// Not threadsafe.
        pub fn wait(s: *S) Cancelable!U {
            s.outstanding -= 1;
            return s.queue.getOne(s.io);
        }

        /// Equivalent to `wait` but requests cancellation on all remaining
        /// tasks owned by the select.
        ///
        /// It is illegal to call `wait` after this.
        ///
        /// Idempotent. Not threadsafe.
        pub fn cancel(s: *S) void {
            s.outstanding = 0;
            s.group.cancel(s.io);
        }
    };
}

pub const Mutex = struct {
    state: State,

    pub const State = enum(usize) {
        locked_once = 0b00,
        unlocked = 0b01,
        contended = 0b10,
        /// contended
        _,

        pub fn isUnlocked(state: State) bool {
            return @intFromEnum(state) & @intFromEnum(State.unlocked) == @intFromEnum(State.unlocked);
        }
    };

    pub const init: Mutex = .{ .state = .unlocked };

    pub fn tryLock(mutex: *Mutex) bool {
        const prev_state: State = @enumFromInt(@atomicRmw(
            usize,
            @as(*usize, @ptrCast(&mutex.state)),
            .And,
            ~@intFromEnum(State.unlocked),
            .acquire,
        ));
        return prev_state.isUnlocked();
    }

    pub fn lock(mutex: *Mutex, io: std.Io) Cancelable!void {
        const prev_state: State = @enumFromInt(@atomicRmw(
            usize,
            @as(*usize, @ptrCast(&mutex.state)),
            .And,
            ~@intFromEnum(State.unlocked),
            .acquire,
        ));
        if (prev_state.isUnlocked()) {
            @branchHint(.likely);
            return;
        }
        return io.vtable.mutexLock(io.userdata, prev_state, mutex);
    }

    /// Same as `lock` but cannot be canceled.
    pub fn lockUncancelable(mutex: *Mutex, io: std.Io) void {
        const prev_state: State = @enumFromInt(@atomicRmw(
            usize,
            @as(*usize, @ptrCast(&mutex.state)),
            .And,
            ~@intFromEnum(State.unlocked),
            .acquire,
        ));
        if (prev_state.isUnlocked()) {
            @branchHint(.likely);
            return;
        }
        return io.vtable.mutexLockUncancelable(io.userdata, prev_state, mutex);
    }

    pub fn unlock(mutex: *Mutex, io: std.Io) void {
        const prev_state = @cmpxchgWeak(State, &mutex.state, .locked_once, .unlocked, .release, .acquire) orelse {
            @branchHint(.likely);
            return;
        };
        assert(prev_state != .unlocked); // mutex not locked
        return io.vtable.mutexUnlock(io.userdata, prev_state, mutex);
    }
};

pub const Condition = struct {
    state: u64 = 0,

    pub fn wait(cond: *Condition, io: Io, mutex: *Mutex) Cancelable!void {
        return io.vtable.conditionWait(io.userdata, cond, mutex);
    }

    pub fn waitUncancelable(cond: *Condition, io: Io, mutex: *Mutex) void {
        return io.vtable.conditionWaitUncancelable(io.userdata, cond, mutex);
    }

    pub fn signal(cond: *Condition, io: Io) void {
        io.vtable.conditionWake(io.userdata, cond, .one);
    }

    pub fn broadcast(cond: *Condition, io: Io) void {
        io.vtable.conditionWake(io.userdata, cond, .all);
    }

    pub const Wake = enum {
        /// Wake up only one thread.
        one,
        /// Wake up all threads.
        all,
    };
};

pub const TypeErasedQueue = struct {
    mutex: Mutex,

    /// Ring buffer. This data is logically *after* queued getters.
    buffer: []u8,
    start: usize,
    len: usize,

    putters: std.DoublyLinkedList,
    getters: std.DoublyLinkedList,

    const Put = struct {
        remaining: []const u8,
        condition: Condition,
        node: std.DoublyLinkedList.Node,
    };

    const Get = struct {
        remaining: []u8,
        condition: Condition,
        node: std.DoublyLinkedList.Node,
    };

    pub fn init(buffer: []u8) TypeErasedQueue {
        return .{
            .mutex = .init,
            .buffer = buffer,
            .start = 0,
            .len = 0,
            .putters = .{},
            .getters = .{},
        };
    }

    pub fn put(q: *TypeErasedQueue, io: Io, elements: []const u8, min: usize) Cancelable!usize {
        assert(elements.len >= min);
        if (elements.len == 0) return 0;
        try q.mutex.lock(io);
        defer q.mutex.unlock(io);
        return q.putLocked(io, elements, min, false);
    }

    /// Same as `put` but cannot be canceled.
    pub fn putUncancelable(q: *TypeErasedQueue, io: Io, elements: []const u8, min: usize) usize {
        assert(elements.len >= min);
        if (elements.len == 0) return 0;
        q.mutex.lockUncancelable(io);
        defer q.mutex.unlock(io);
        return q.putLocked(io, elements, min, true) catch |err| switch (err) {
            error.Canceled => unreachable,
        };
    }

    fn puttableSlice(q: *const TypeErasedQueue) ?[]u8 {
        const unwrapped_index = q.start + q.len;
        const wrapped_index, const overflow = @subWithOverflow(unwrapped_index, q.buffer.len);
        const slice = switch (overflow) {
            1 => q.buffer[unwrapped_index..],
            0 => q.buffer[wrapped_index..q.start],
        };
        return if (slice.len > 0) slice else null;
    }

    fn putLocked(q: *TypeErasedQueue, io: Io, elements: []const u8, min: usize, uncancelable: bool) Cancelable!usize {
        // Getters have first priority on the data, and only when the getters
        // queue is empty do we start populating the buffer.

        var remaining = elements;
        while (q.getters.popFirst()) |getter_node| {
            const getter: *Get = @alignCast(@fieldParentPtr("node", getter_node));
            const copy_len = @min(getter.remaining.len, remaining.len);
            assert(copy_len > 0);
            @memcpy(getter.remaining[0..copy_len], remaining[0..copy_len]);
            remaining = remaining[copy_len..];
            getter.remaining = getter.remaining[copy_len..];
            if (getter.remaining.len == 0) {
                getter.condition.signal(io);
                if (remaining.len > 0) continue;
            } else q.getters.prepend(getter_node);
            assert(remaining.len == 0);
            return elements.len;
        }

        while (q.puttableSlice()) |slice| {
            const copy_len = @min(slice.len, remaining.len);
            assert(copy_len > 0);
            @memcpy(slice[0..copy_len], remaining[0..copy_len]);
            q.len += copy_len;
            remaining = remaining[copy_len..];
            if (remaining.len == 0) return elements.len;
        }

        const total_filled = elements.len - remaining.len;
        if (total_filled >= min) return total_filled;

        var pending: Put = .{ .remaining = remaining, .condition = .{}, .node = .{} };
        q.putters.append(&pending.node);
        defer if (pending.remaining.len > 0) q.putters.remove(&pending.node);
        while (pending.remaining.len > 0) if (uncancelable)
            pending.condition.waitUncancelable(io, &q.mutex)
        else
            try pending.condition.wait(io, &q.mutex);
        return elements.len;
    }

    pub fn get(q: *@This(), io: Io, buffer: []u8, min: usize) Cancelable!usize {
        assert(buffer.len >= min);
        if (buffer.len == 0) return 0;
        try q.mutex.lock(io);
        defer q.mutex.unlock(io);
        return q.getLocked(io, buffer, min, false);
    }

    pub fn getUncancelable(q: *@This(), io: Io, buffer: []u8, min: usize) usize {
        assert(buffer.len >= min);
        if (buffer.len == 0) return 0;
        q.mutex.lockUncancelable(io);
        defer q.mutex.unlock(io);
        return q.getLocked(io, buffer, min, true) catch |err| switch (err) {
            error.Canceled => unreachable,
        };
    }

    fn gettableSlice(q: *const TypeErasedQueue) ?[]const u8 {
        const overlong_slice = q.buffer[q.start..];
        const slice = overlong_slice[0..@min(overlong_slice.len, q.len)];
        return if (slice.len > 0) slice else null;
    }

    fn getLocked(q: *@This(), io: Io, buffer: []u8, min: usize, uncancelable: bool) Cancelable!usize {
        // The ring buffer gets first priority, then data should come from any
        // queued putters, then finally the ring buffer should be filled with
        // data from putters so they can be resumed.

        var remaining = buffer;
        while (q.gettableSlice()) |slice| {
            const copy_len = @min(slice.len, remaining.len);
            assert(copy_len > 0);
            @memcpy(remaining[0..copy_len], slice[0..copy_len]);
            q.start += copy_len;
            if (q.buffer.len - q.start == 0) q.start = 0;
            q.len -= copy_len;
            remaining = remaining[copy_len..];
            if (remaining.len == 0) {
                q.fillRingBufferFromPutters(io);
                return buffer.len;
            }
        }

        // Copy directly from putters into buffer.
        while (q.putters.popFirst()) |putter_node| {
            const putter: *Put = @alignCast(@fieldParentPtr("node", putter_node));
            const copy_len = @min(putter.remaining.len, remaining.len);
            assert(copy_len > 0);
            @memcpy(remaining[0..copy_len], putter.remaining[0..copy_len]);
            putter.remaining = putter.remaining[copy_len..];
            remaining = remaining[copy_len..];
            if (putter.remaining.len == 0) {
                putter.condition.signal(io);
                if (remaining.len > 0) continue;
            } else q.putters.prepend(putter_node);
            assert(remaining.len == 0);
            q.fillRingBufferFromPutters(io);
            return buffer.len;
        }

        // Both ring buffer and putters queue is empty.
        const total_filled = buffer.len - remaining.len;
        if (total_filled >= min) return total_filled;

        var pending: Get = .{ .remaining = remaining, .condition = .{}, .node = .{} };
        q.getters.append(&pending.node);
        defer if (pending.remaining.len > 0) q.getters.remove(&pending.node);
        while (pending.remaining.len > 0) if (uncancelable)
            pending.condition.waitUncancelable(io, &q.mutex)
        else
            try pending.condition.wait(io, &q.mutex);
        q.fillRingBufferFromPutters(io);
        return buffer.len;
    }

    /// Called when there is nonzero space available in the ring buffer and
    /// potentially putters waiting. The mutex is already held and the task is
    /// to copy putter data to the ring buffer and signal any putters whose
    /// buffers been fully copied.
    fn fillRingBufferFromPutters(q: *TypeErasedQueue, io: Io) void {
        while (q.putters.popFirst()) |putter_node| {
            const putter: *Put = @alignCast(@fieldParentPtr("node", putter_node));
            while (q.puttableSlice()) |slice| {
                const copy_len = @min(slice.len, putter.remaining.len);
                assert(copy_len > 0);
                @memcpy(slice[0..copy_len], putter.remaining[0..copy_len]);
                q.len += copy_len;
                putter.remaining = putter.remaining[copy_len..];
                if (putter.remaining.len == 0) {
                    putter.condition.signal(io);
                    break;
                }
            } else {
                q.putters.prepend(putter_node);
                break;
            }
        }
    }
};

/// Many producer, many consumer, thread-safe, runtime configurable buffer size.
/// When buffer is empty, consumers suspend and are resumed by producers.
/// When buffer is full, producers suspend and are resumed by consumers.
pub fn Queue(Elem: type) type {
    return struct {
        type_erased: TypeErasedQueue,

        pub fn init(buffer: []Elem) @This() {
            return .{ .type_erased = .init(@ptrCast(buffer)) };
        }

        /// Appends elements to the end of the queue. The function returns when
        /// at least `min` elements have been added to the buffer or sent
        /// directly to a consumer.
        ///
        /// Returns how many elements have been added to the queue.
        ///
        /// Asserts that `elements.len >= min`.
        pub fn put(q: *@This(), io: Io, elements: []const Elem, min: usize) Cancelable!usize {
            return @divExact(try q.type_erased.put(io, @ptrCast(elements), min * @sizeOf(Elem)), @sizeOf(Elem));
        }

        /// Same as `put` but blocks until all elements have been added to the queue.
        pub fn putAll(q: *@This(), io: Io, elements: []const Elem) Cancelable!void {
            assert(try q.put(io, elements, elements.len) == elements.len);
        }

        /// Same as `put` but cannot be interrupted.
        pub fn putUncancelable(q: *@This(), io: Io, elements: []const Elem, min: usize) usize {
            return @divExact(q.type_erased.putUncancelable(io, @ptrCast(elements), min * @sizeOf(Elem)), @sizeOf(Elem));
        }

        pub fn putOne(q: *@This(), io: Io, item: Elem) Cancelable!void {
            assert(try q.put(io, &.{item}, 1) == 1);
        }

        pub fn putOneUncancelable(q: *@This(), io: Io, item: Elem) void {
            assert(q.putUncancelable(io, &.{item}, 1) == 1);
        }

        /// Receives elements from the beginning of the queue. The function
        /// returns when at least `min` elements have been populated inside
        /// `buffer`.
        ///
        /// Returns how many elements of `buffer` have been populated.
        ///
        /// Asserts that `buffer.len >= min`.
        pub fn get(q: *@This(), io: Io, buffer: []Elem, min: usize) Cancelable!usize {
            return @divExact(try q.type_erased.get(io, @ptrCast(buffer), min * @sizeOf(Elem)), @sizeOf(Elem));
        }

        pub fn getUncancelable(q: *@This(), io: Io, buffer: []Elem, min: usize) usize {
            return @divExact(q.type_erased.getUncancelable(io, @ptrCast(buffer), min * @sizeOf(Elem)), @sizeOf(Elem));
        }

        pub fn getOne(q: *@This(), io: Io) Cancelable!Elem {
            var buf: [1]Elem = undefined;
            assert(try q.get(io, &buf, 1) == 1);
            return buf[0];
        }

        pub fn getOneUncancelable(q: *@This(), io: Io) Elem {
            var buf: [1]Elem = undefined;
            assert(q.getUncancelable(io, &buf, 1) == 1);
            return buf[0];
        }

        /// Returns buffer length in `Elem` units.
        pub fn capacity(q: *const @This()) usize {
            return @divExact(q.type_erased.buffer.len, @sizeOf(Elem));
        }
    };
}

/// Calls `function` with `args`, such that the return value of the function is
/// not guaranteed to be available until `await` is called.
///
/// `function` *may* be called immediately, before `async` returns. This has
/// weaker guarantees than `concurrent`, making more portable and reusable.
///
/// When this function returns, it is guaranteed that `function` has already
/// been called and completed, or it has successfully been assigned a unit of
/// concurrency.
///
/// See also:
/// * `Group`
pub fn async(
    io: Io,
    function: anytype,
    args: std.meta.ArgsTuple(@TypeOf(function)),
) Future(@typeInfo(@TypeOf(function)).@"fn".return_type.?) {
    const Result = @typeInfo(@TypeOf(function)).@"fn".return_type.?;
    const Args = @TypeOf(args);
    const TypeErased = struct {
        fn start(context: *const anyopaque, result: *anyopaque) void {
            const args_casted: *const Args = @ptrCast(@alignCast(context));
            const result_casted: *Result = @ptrCast(@alignCast(result));
            result_casted.* = @call(.auto, function, args_casted.*);
        }
    };
    var future: Future(Result) = undefined;
    future.any_future = io.vtable.async(
        io.userdata,
        @ptrCast(&future.result),
        .of(Result),
        @ptrCast(&args),
        .of(Args),
        TypeErased.start,
    );
    return future;
}

pub const ConcurrentError = error{
    /// May occur due to a temporary condition such as resource exhaustion, or
    /// to the Io implementation not supporting concurrency.
    ConcurrencyUnavailable,
};

/// Calls `function` with `args`, such that the return value of the function is
/// not guaranteed to be available until `await` is called, allowing the caller
/// to progress while waiting for any `Io` operations.
///
/// This has stronger guarantee than `async`, placing restrictions on what kind
/// of `Io` implementations are supported. By calling `async` instead, one
/// allows, for example, stackful single-threaded blocking I/O.
pub fn concurrent(
    io: Io,
    function: anytype,
    args: std.meta.ArgsTuple(@TypeOf(function)),
) ConcurrentError!Future(@typeInfo(@TypeOf(function)).@"fn".return_type.?) {
    const Result = @typeInfo(@TypeOf(function)).@"fn".return_type.?;
    const Args = @TypeOf(args);
    const TypeErased = struct {
        fn start(context: *const anyopaque, result: *anyopaque) void {
            const args_casted: *const Args = @ptrCast(@alignCast(context));
            const result_casted: *Result = @ptrCast(@alignCast(result));
            result_casted.* = @call(.auto, function, args_casted.*);
        }
    };
    var future: Future(Result) = undefined;
    future.any_future = try io.vtable.concurrent(
        io.userdata,
        @sizeOf(Result),
        .of(Result),
        @ptrCast(&args),
        .of(Args),
        TypeErased.start,
    );
    return future;
}

pub fn cancelRequested(io: Io) bool {
    return io.vtable.cancelRequested(io.userdata);
}

pub const SleepError = error{UnsupportedClock} || UnexpectedError || Cancelable;

pub fn sleep(io: Io, duration: Duration, clock: Clock) SleepError!void {
    return io.vtable.sleep(io.userdata, .{ .duration = .{
        .raw = duration,
        .clock = clock,
    } });
}

/// Given a struct with each field a `*Future`, returns a union with the same
/// fields, each field type the future's result.
pub fn SelectUnion(S: type) type {
    const struct_fields = @typeInfo(S).@"struct".fields;
    var fields: [struct_fields.len]std.builtin.Type.UnionField = undefined;
    for (&fields, struct_fields) |*union_field, struct_field| {
        const F = @typeInfo(struct_field.type).pointer.child;
        const Result = @TypeOf(@as(F, undefined).result);
        union_field.* = .{
            .name = struct_field.name,
            .type = Result,
            .alignment = struct_field.alignment,
        };
    }
    return @Type(.{ .@"union" = .{
        .layout = .auto,
        .tag_type = std.meta.FieldEnum(S),
        .fields = &fields,
        .decls = &.{},
    } });
}

/// `s` is a struct with every field a `*Future(T)`, where `T` can be any type,
/// and can be different for each field.
pub fn select(io: Io, s: anytype) Cancelable!SelectUnion(@TypeOf(s)) {
    const U = SelectUnion(@TypeOf(s));
    const S = @TypeOf(s);
    const fields = @typeInfo(S).@"struct".fields;
    var futures: [fields.len]*AnyFuture = undefined;
    inline for (fields, &futures) |field, *any_future| {
        const future = @field(s, field.name);
        any_future.* = future.any_future orelse return @unionInit(U, field.name, future.result);
    }
    switch (try io.vtable.select(io.userdata, &futures)) {
        inline 0...(fields.len - 1) => |selected_index| {
            const field_name = fields[selected_index].name;
            return @unionInit(U, field_name, @field(s, field_name).await(io));
        },
        else => unreachable,
    }
}
