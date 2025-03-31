const builtin = @import("builtin");
const is_windows = builtin.os.tag == .windows;

const std = @import("std.zig");
const windows = std.os.windows;
const posix = std.posix;
const math = std.math;
const assert = std.debug.assert;
const fs = std.fs;
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
                var list: std.ArrayListUnmanaged(u8) = .{
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
    _ = Reader;
    _ = Writer;
    _ = tty;
    _ = @import("Io/test.zig");
}

const Io = @This();

pub const EventLoop = @import("Io/EventLoop.zig");

userdata: ?*anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// If it returns `null` it means `result` has been already populated and
    /// `await` will be a no-op.
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

    mutexLock: *const fn (?*anyopaque, mutex: *Mutex) void,
    mutexUnlock: *const fn (?*anyopaque, mutex: *Mutex) void,

    conditionWait: *const fn (?*anyopaque, cond: *Condition, mutex: *Mutex, timeout_ns: ?u64) Condition.WaitError!void,
    conditionWake: *const fn (?*anyopaque, cond: *Condition, notify: Condition.Notify) void,

    createFile: *const fn (?*anyopaque, dir: fs.Dir, sub_path: []const u8, flags: fs.File.CreateFlags) FileOpenError!fs.File,
    openFile: *const fn (?*anyopaque, dir: fs.Dir, sub_path: []const u8, flags: fs.File.OpenFlags) FileOpenError!fs.File,
    closeFile: *const fn (?*anyopaque, fs.File) void,
    pread: *const fn (?*anyopaque, file: fs.File, buffer: []u8, offset: std.posix.off_t) FilePReadError!usize,
    pwrite: *const fn (?*anyopaque, file: fs.File, buffer: []const u8, offset: std.posix.off_t) FilePWriteError!usize,

    now: *const fn (?*anyopaque, clockid: std.posix.clockid_t) ClockGetTimeError!Timestamp,
    sleep: *const fn (?*anyopaque, clockid: std.posix.clockid_t, deadline: Deadline) SleepError!void,
};

pub const OpenFlags = fs.File.OpenFlags;
pub const CreateFlags = fs.File.CreateFlags;

pub const FileOpenError = fs.File.OpenError || error{Canceled};
pub const FileReadError = fs.File.ReadError || error{Canceled};
pub const FilePReadError = fs.File.PReadError || error{Canceled};
pub const FileWriteError = fs.File.WriteError || error{Canceled};
pub const FilePWriteError = fs.File.PWriteError || error{Canceled};

pub const Timestamp = enum(i96) {
    _,

    pub fn durationTo(from: Timestamp, to: Timestamp) i96 {
        return @intFromEnum(to) - @intFromEnum(from);
    }

    pub fn addDuration(from: Timestamp, duration: i96) Timestamp {
        return @enumFromInt(@intFromEnum(from) + duration);
    }
};
pub const Deadline = union(enum) {
    nanoseconds: i96,
    timestamp: Timestamp,
};
pub const ClockGetTimeError = std.posix.ClockGetTimeError || error{Canceled};
pub const SleepError = error{ UnsupportedClock, Unexpected, Canceled };

pub const AnyFuture = opaque {};

pub fn Future(Result: type) type {
    return struct {
        any_future: ?*AnyFuture,
        result: Result,

        /// Equivalent to `await` but sets a flag observable to application
        /// code that cancellation has been requested.
        ///
        /// Idempotent.
        pub fn cancel(f: *@This(), io: Io) Result {
            const any_future = f.any_future orelse return f.result;
            io.vtable.cancel(io.userdata, any_future, @ptrCast((&f.result)[0..1]), .of(Result));
            f.any_future = null;
            return f.result;
        }

        pub fn await(f: *@This(), io: Io) Result {
            const any_future = f.any_future orelse return f.result;
            io.vtable.await(io.userdata, any_future, @ptrCast((&f.result)[0..1]), .of(Result));
            f.any_future = null;
            return f.result;
        }
    };
}

pub const Mutex = struct {
    state: std.atomic.Value(u32) = std.atomic.Value(u32).init(unlocked),

    pub const unlocked: u32 = 0b00;
    pub const locked: u32 = 0b01;
    pub const contended: u32 = 0b11; // must contain the `locked` bit for x86 optimization below

    pub fn tryLock(m: *Mutex) bool {
        // On x86, use `lock bts` instead of `lock cmpxchg` as:
        // - they both seem to mark the cache-line as modified regardless: https://stackoverflow.com/a/63350048
        // - `lock bts` is smaller instruction-wise which makes it better for inlining
        if (builtin.target.cpu.arch.isX86()) {
            const locked_bit = @ctz(locked);
            return m.state.bitSet(locked_bit, .acquire) == 0;
        }

        // Acquire barrier ensures grabbing the lock happens before the critical section
        // and that the previous lock holder's critical section happens before we grab the lock.
        return m.state.cmpxchgWeak(unlocked, locked, .acquire, .monotonic) == null;
    }

    /// Avoids the vtable for uncontended locks.
    pub fn lock(m: *Mutex, io: Io) void {
        if (!m.tryLock()) {
            @branchHint(.unlikely);
            io.vtable.mutexLock(io.userdata, m);
        }
    }

    pub fn unlock(m: *Mutex, io: Io) void {
        io.vtable.mutexUnlock(io.userdata, m);
    }
};

pub const Condition = struct {
    state: u64 = 0,

    pub const WaitError = error{
        Timeout,
        Canceled,
    };

    /// How many waiters to wake up.
    pub const Notify = enum {
        one,
        all,
    };

    pub fn wait(cond: *Condition, io: Io, mutex: *Mutex) void {
        io.vtable.conditionWait(io.userdata, cond, mutex, null) catch |err| switch (err) {
            error.Timeout => unreachable, // no timeout provided so we shouldn't have timed-out
            error.Canceled => return, // handled as spurious wakeup
        };
    }

    pub fn timedWait(cond: *Condition, io: Io, mutex: *Mutex, timeout_ns: u64) WaitError!void {
        return io.vtable.conditionWait(io.userdata, cond, mutex, timeout_ns);
    }

    pub fn signal(cond: *Condition, io: Io) void {
        io.vtable.conditionWake(io.userdata, cond, .one);
    }

    pub fn broadcast(cond: *Condition, io: Io) void {
        io.vtable.conditionWake(io.userdata, cond, .all);
    }
};

pub const TypeErasedQueue = struct {
    mutex: Mutex,

    /// Ring buffer. This data is logically *after* queued getters.
    buffer: []u8,
    put_index: usize,
    get_index: usize,

    putters: std.DoublyLinkedList(PutNode),
    getters: std.DoublyLinkedList(GetNode),

    const PutNode = struct {
        remaining: []const u8,
        condition: Condition,
    };

    const GetNode = struct {
        remaining: []u8,
        condition: Condition,
    };

    pub fn init(buffer: []u8) TypeErasedQueue {
        return .{
            .mutex = .{},
            .buffer = buffer,
            .put_index = 0,
            .get_index = 0,
            .putters = .{},
            .getters = .{},
        };
    }

    pub fn put(q: *TypeErasedQueue, io: Io, elements: []const u8, min: usize) usize {
        assert(elements.len >= min);

        q.mutex.lock(io);
        defer q.mutex.unlock(io);

        // Getters have first priority on the data, and only when the getters
        // queue is empty do we start populating the buffer.

        var remaining = elements;
        while (true) {
            const getter = q.getters.popFirst() orelse break;
            const copy_len = @min(getter.data.remaining.len, remaining.len);
            @memcpy(getter.data.remaining[0..copy_len], remaining[0..copy_len]);
            remaining = remaining[copy_len..];
            getter.data.remaining = getter.data.remaining[copy_len..];
            if (getter.data.remaining.len == 0) {
                getter.data.condition.signal(io);
                continue;
            }
            q.getters.prepend(getter);
            assert(remaining.len == 0);
            return elements.len;
        }

        while (true) {
            {
                const available = q.buffer[q.put_index..];
                const copy_len = @min(available.len, remaining.len);
                @memcpy(available[0..copy_len], remaining[0..copy_len]);
                remaining = remaining[copy_len..];
                q.put_index += copy_len;
                if (remaining.len == 0) return elements.len;
            }
            {
                const available = q.buffer[0..q.get_index];
                const copy_len = @min(available.len, remaining.len);
                @memcpy(available[0..copy_len], remaining[0..copy_len]);
                remaining = remaining[copy_len..];
                q.put_index = copy_len;
                if (remaining.len == 0) return elements.len;
            }

            const total_filled = elements.len - remaining.len;
            if (total_filled >= min) return total_filled;

            var node: std.DoublyLinkedList(PutNode).Node = .{
                .data = .{ .remaining = remaining, .condition = .{} },
            };
            q.putters.append(&node);
            node.data.condition.wait(io, &q.mutex);
            remaining = node.data.remaining;
        }
    }

    pub fn get(q: *@This(), io: Io, buffer: []u8, min: usize) usize {
        assert(buffer.len >= min);

        q.mutex.lock(io);
        defer q.mutex.unlock(io);

        // The ring buffer gets first priority, then data should come from any
        // queued putters, then finally the ring buffer should be filled with
        // data from putters so they can be resumed.

        var remaining = buffer;
        while (true) {
            if (q.get_index <= q.put_index) {
                const available = q.buffer[q.get_index..q.put_index];
                const copy_len = @min(available.len, remaining.len);
                @memcpy(remaining[0..copy_len], available[0..copy_len]);
                q.get_index += copy_len;
                remaining = remaining[copy_len..];
                if (remaining.len == 0) return fillRingBufferFromPutters(q, io, buffer.len);
            } else {
                {
                    const available = q.buffer[q.get_index..];
                    const copy_len = @min(available.len, remaining.len);
                    @memcpy(remaining[0..copy_len], available[0..copy_len]);
                    q.get_index += copy_len;
                    remaining = remaining[copy_len..];
                    if (remaining.len == 0) return fillRingBufferFromPutters(q, io, buffer.len);
                }
                {
                    const available = q.buffer[0..q.put_index];
                    const copy_len = @min(available.len, remaining.len);
                    @memcpy(remaining[0..copy_len], available[0..copy_len]);
                    q.get_index = copy_len;
                    remaining = remaining[copy_len..];
                    if (remaining.len == 0) return fillRingBufferFromPutters(q, io, buffer.len);
                }
            }
            // Copy directly from putters into buffer.
            while (remaining.len > 0) {
                const putter = q.putters.popFirst() orelse break;
                const copy_len = @min(putter.data.remaining.len, remaining.len);
                @memcpy(remaining[0..copy_len], putter.data.remaining[0..copy_len]);
                putter.data.remaining = putter.data.remaining[copy_len..];
                remaining = remaining[copy_len..];
                if (putter.data.remaining.len == 0) {
                    putter.data.condition.signal(io);
                } else {
                    assert(remaining.len == 0);
                    q.putters.prepend(putter);
                    return fillRingBufferFromPutters(q, io, buffer.len);
                }
            }
            // Both ring buffer and putters queue is empty.
            const total_filled = buffer.len - remaining.len;
            if (total_filled >= min) return total_filled;

            var node: std.DoublyLinkedList(GetNode).Node = .{
                .data = .{ .remaining = remaining, .condition = .{} },
            };
            q.getters.append(&node);
            node.data.condition.wait(io, &q.mutex);
            remaining = node.data.remaining;
        }
    }

    /// Called when there is nonzero space available in the ring buffer and
    /// potentially putters waiting. The mutex is already held and the task is
    /// to copy putter data to the ring buffer and signal any putters whose
    /// buffers been fully copied.
    fn fillRingBufferFromPutters(q: *TypeErasedQueue, io: Io, len: usize) usize {
        while (true) {
            const putter = q.putters.popFirst() orelse return len;
            const available = q.buffer[q.put_index..];
            const copy_len = @min(available.len, putter.data.remaining.len);
            @memcpy(available[0..copy_len], putter.data.remaining[0..copy_len]);
            putter.data.remaining = putter.data.remaining[copy_len..];
            q.put_index += copy_len;
            if (putter.data.remaining.len == 0) {
                putter.data.condition.signal(io);
                continue;
            }
            const second_available = q.buffer[0..q.get_index];
            const second_copy_len = @min(second_available.len, putter.data.remaining.len);
            @memcpy(second_available[0..second_copy_len], putter.data.remaining[0..second_copy_len]);
            putter.data.remaining = putter.data.remaining[copy_len..];
            q.put_index = copy_len;
            if (putter.data.remaining.len == 0) {
                putter.data.condition.signal(io);
                continue;
            }
            q.putters.prepend(putter);
            return len;
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
        pub fn put(q: *@This(), io: Io, elements: []const Elem, min: usize) usize {
            return @divExact(q.type_erased.put(io, @ptrCast(elements), min * @sizeOf(Elem)), @sizeOf(Elem));
        }

        /// Receives elements from the beginning of the queue. The function
        /// returns when at least `min` elements have been populated inside
        /// `buffer`.
        ///
        /// Returns how many elements of `buffer` have been populated.
        ///
        /// Asserts that `buffer.len >= min`.
        pub fn get(q: *@This(), io: Io, buffer: []Elem, min: usize) usize {
            return @divExact(q.type_erased.get(io, @ptrCast(buffer), min * @sizeOf(Elem)), @sizeOf(Elem));
        }

        pub fn putOne(q: *@This(), io: Io, item: Elem) void {
            assert(q.put(io, &.{item}, 1) == 1);
        }

        pub fn getOne(q: *@This(), io: Io) Elem {
            var buf: [1]Elem = undefined;
            assert(q.get(io, &buf, 1) == 1);
            return buf[0];
        }
    };
}

/// Calls `function` with `args`, such that the return value of the function is
/// not guaranteed to be available until `await` is called.
pub fn async(io: Io, function: anytype, args: anytype) Future(@typeInfo(@TypeOf(function)).@"fn".return_type.?) {
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
        @ptrCast((&future.result)[0..1]),
        .of(Result),
        if (@sizeOf(Args) == 0) &.{} else @ptrCast((&args)[0..1]), // work around compiler bug
        .of(Args),
        TypeErased.start,
    );
    return future;
}

pub fn openFile(io: Io, dir: fs.Dir, sub_path: []const u8, flags: fs.File.OpenFlags) FileOpenError!fs.File {
    return io.vtable.openFile(io.userdata, dir, sub_path, flags);
}

pub fn createFile(io: Io, dir: fs.Dir, sub_path: []const u8, flags: fs.File.CreateFlags) FileOpenError!fs.File {
    return io.vtable.createFile(io.userdata, dir, sub_path, flags);
}

pub fn closeFile(io: Io, file: fs.File) void {
    return io.vtable.closeFile(io.userdata, file);
}

pub fn read(io: Io, file: fs.File, buffer: []u8) FileReadError!usize {
    return @errorCast(io.pread(file, buffer, -1));
}

pub fn pread(io: Io, file: fs.File, buffer: []u8, offset: std.posix.off_t) FilePReadError!usize {
    return io.vtable.pread(io.userdata, file, buffer, offset);
}

pub fn write(io: Io, file: fs.File, buffer: []const u8) FileWriteError!usize {
    return @errorCast(io.pwrite(file, buffer, -1));
}

pub fn pwrite(io: Io, file: fs.File, buffer: []const u8, offset: std.posix.off_t) FilePWriteError!usize {
    return io.vtable.pwrite(io.userdata, file, buffer, offset);
}

pub fn writeAll(io: Io, file: fs.File, bytes: []const u8) FileWriteError!void {
    var index: usize = 0;
    while (index < bytes.len) {
        index += try io.write(file, bytes[index..]);
    }
}

pub fn readAll(io: Io, file: fs.File, buffer: []u8) FileReadError!usize {
    var index: usize = 0;
    while (index != buffer.len) {
        const amt = try io.read(file, buffer[index..]);
        if (amt == 0) break;
        index += amt;
    }
    return index;
}

pub fn now(io: Io, clockid: std.posix.clockid_t) ClockGetTimeError!Timestamp {
    return io.vtable.now(io.userdata, clockid);
}

pub fn sleep(io: Io, clockid: std.posix.clockid_t, deadline: Deadline) SleepError!void {
    return io.vtable.sleep(io.userdata, clockid, deadline);
}
