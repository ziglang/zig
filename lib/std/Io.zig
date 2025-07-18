const builtin = @import("builtin");
const std = @import("std.zig");
const is_windows = builtin.os.tag == .windows;
const windows = std.os.windows;
const posix = std.posix;
const math = std.math;
const assert = std.debug.assert;
const fs = std.fs;
const mem = std.mem;
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

/// Deprecated in favor of `Reader`.
pub fn GenericReader(
    comptime Context: type,
    comptime ReadError: type,
    /// Returns the number of bytes read. It may be less than buffer.len.
    /// If the number of bytes read is 0, it means end of stream.
    /// End of stream is not an error condition.
    comptime readFn: fn (context: Context, buffer: []u8) ReadError!usize,
) type {
    return struct {
        context: Context,

        pub const Error = ReadError;
        pub const NoEofError = ReadError || error{
            EndOfStream,
        };

        pub inline fn read(self: Self, buffer: []u8) Error!usize {
            return readFn(self.context, buffer);
        }

        pub inline fn readAll(self: Self, buffer: []u8) Error!usize {
            return @errorCast(self.any().readAll(buffer));
        }

        pub inline fn readAtLeast(self: Self, buffer: []u8, len: usize) Error!usize {
            return @errorCast(self.any().readAtLeast(buffer, len));
        }

        pub inline fn readNoEof(self: Self, buf: []u8) NoEofError!void {
            return @errorCast(self.any().readNoEof(buf));
        }

        pub inline fn readAllArrayList(
            self: Self,
            array_list: *std.ArrayList(u8),
            max_append_size: usize,
        ) (error{StreamTooLong} || Allocator.Error || Error)!void {
            return @errorCast(self.any().readAllArrayList(array_list, max_append_size));
        }

        pub inline fn readAllArrayListAligned(
            self: Self,
            comptime alignment: ?Alignment,
            array_list: *std.ArrayListAligned(u8, alignment),
            max_append_size: usize,
        ) (error{StreamTooLong} || Allocator.Error || Error)!void {
            return @errorCast(self.any().readAllArrayListAligned(
                alignment,
                array_list,
                max_append_size,
            ));
        }

        pub inline fn readAllAlloc(
            self: Self,
            allocator: Allocator,
            max_size: usize,
        ) (Error || Allocator.Error || error{StreamTooLong})![]u8 {
            return @errorCast(self.any().readAllAlloc(allocator, max_size));
        }

        pub inline fn readUntilDelimiterArrayList(
            self: Self,
            array_list: *std.ArrayList(u8),
            delimiter: u8,
            max_size: usize,
        ) (NoEofError || Allocator.Error || error{StreamTooLong})!void {
            return @errorCast(self.any().readUntilDelimiterArrayList(
                array_list,
                delimiter,
                max_size,
            ));
        }

        pub inline fn readUntilDelimiterAlloc(
            self: Self,
            allocator: Allocator,
            delimiter: u8,
            max_size: usize,
        ) (NoEofError || Allocator.Error || error{StreamTooLong})![]u8 {
            return @errorCast(self.any().readUntilDelimiterAlloc(
                allocator,
                delimiter,
                max_size,
            ));
        }

        pub inline fn readUntilDelimiter(
            self: Self,
            buf: []u8,
            delimiter: u8,
        ) (NoEofError || error{StreamTooLong})![]u8 {
            return @errorCast(self.any().readUntilDelimiter(buf, delimiter));
        }

        pub inline fn readUntilDelimiterOrEofAlloc(
            self: Self,
            allocator: Allocator,
            delimiter: u8,
            max_size: usize,
        ) (Error || Allocator.Error || error{StreamTooLong})!?[]u8 {
            return @errorCast(self.any().readUntilDelimiterOrEofAlloc(
                allocator,
                delimiter,
                max_size,
            ));
        }

        pub inline fn readUntilDelimiterOrEof(
            self: Self,
            buf: []u8,
            delimiter: u8,
        ) (Error || error{StreamTooLong})!?[]u8 {
            return @errorCast(self.any().readUntilDelimiterOrEof(buf, delimiter));
        }

        pub inline fn streamUntilDelimiter(
            self: Self,
            writer: anytype,
            delimiter: u8,
            optional_max_size: ?usize,
        ) (NoEofError || error{StreamTooLong} || @TypeOf(writer).Error)!void {
            return @errorCast(self.any().streamUntilDelimiter(
                writer,
                delimiter,
                optional_max_size,
            ));
        }

        pub inline fn skipUntilDelimiterOrEof(self: Self, delimiter: u8) Error!void {
            return @errorCast(self.any().skipUntilDelimiterOrEof(delimiter));
        }

        pub inline fn readByte(self: Self) NoEofError!u8 {
            return @errorCast(self.any().readByte());
        }

        pub inline fn readByteSigned(self: Self) NoEofError!i8 {
            return @errorCast(self.any().readByteSigned());
        }

        pub inline fn readBytesNoEof(
            self: Self,
            comptime num_bytes: usize,
        ) NoEofError![num_bytes]u8 {
            return @errorCast(self.any().readBytesNoEof(num_bytes));
        }

        pub inline fn readIntoBoundedBytes(
            self: Self,
            comptime num_bytes: usize,
            bounded: *std.BoundedArray(u8, num_bytes),
        ) Error!void {
            return @errorCast(self.any().readIntoBoundedBytes(num_bytes, bounded));
        }

        pub inline fn readBoundedBytes(
            self: Self,
            comptime num_bytes: usize,
        ) Error!std.BoundedArray(u8, num_bytes) {
            return @errorCast(self.any().readBoundedBytes(num_bytes));
        }

        pub inline fn readInt(self: Self, comptime T: type, endian: std.builtin.Endian) NoEofError!T {
            return @errorCast(self.any().readInt(T, endian));
        }

        pub inline fn readVarInt(
            self: Self,
            comptime ReturnType: type,
            endian: std.builtin.Endian,
            size: usize,
        ) NoEofError!ReturnType {
            return @errorCast(self.any().readVarInt(ReturnType, endian, size));
        }

        pub const SkipBytesOptions = AnyReader.SkipBytesOptions;

        pub inline fn skipBytes(
            self: Self,
            num_bytes: u64,
            comptime options: SkipBytesOptions,
        ) NoEofError!void {
            return @errorCast(self.any().skipBytes(num_bytes, options));
        }

        pub inline fn isBytes(self: Self, slice: []const u8) NoEofError!bool {
            return @errorCast(self.any().isBytes(slice));
        }

        pub inline fn readStruct(self: Self, comptime T: type) NoEofError!T {
            return @errorCast(self.any().readStruct(T));
        }

        pub inline fn readStructEndian(self: Self, comptime T: type, endian: std.builtin.Endian) NoEofError!T {
            return @errorCast(self.any().readStructEndian(T, endian));
        }

        pub const ReadEnumError = NoEofError || error{
            /// An integer was read, but it did not match any of the tags in the supplied enum.
            InvalidValue,
        };

        pub inline fn readEnum(
            self: Self,
            comptime Enum: type,
            endian: std.builtin.Endian,
        ) ReadEnumError!Enum {
            return @errorCast(self.any().readEnum(Enum, endian));
        }

        pub inline fn any(self: *const Self) AnyReader {
            return .{
                .context = @ptrCast(&self.context),
                .readFn = typeErasedReadFn,
            };
        }

        const Self = @This();

        fn typeErasedReadFn(context: *const anyopaque, buffer: []u8) anyerror!usize {
            const ptr: *const Context = @alignCast(@ptrCast(context));
            return readFn(ptr.*, buffer);
        }

        /// Helper for bridging to the new `Reader` API while upgrading.
        pub fn adaptToNewApi(self: *const Self) Adapter {
            return .{
                .derp_reader = self.*,
                .new_interface = .{
                    .buffer = &.{},
                    .vtable = &.{ .stream = Adapter.stream },
                    .seek = 0,
                    .end = 0,
                },
            };
        }

        pub const Adapter = struct {
            derp_reader: Self,
            new_interface: Reader,
            err: ?Error = null,

            fn stream(r: *Reader, w: *Writer, limit: Limit) Reader.StreamError!usize {
                const a: *@This() = @alignCast(@fieldParentPtr("new_interface", r));
                const buf = limit.slice(try w.writableSliceGreedy(1));
                return a.derp_reader.read(buf) catch |err| {
                    a.err = err;
                    return error.ReadFailed;
                };
            }
        };
    };
}

/// Deprecated in favor of `Writer`.
pub fn GenericWriter(
    comptime Context: type,
    comptime WriteError: type,
    comptime writeFn: fn (context: Context, bytes: []const u8) WriteError!usize,
) type {
    return struct {
        context: Context,

        const Self = @This();
        pub const Error = WriteError;

        pub inline fn write(self: Self, bytes: []const u8) Error!usize {
            return writeFn(self.context, bytes);
        }

        pub inline fn writeAll(self: Self, bytes: []const u8) Error!void {
            return @errorCast(self.any().writeAll(bytes));
        }

        pub inline fn print(self: Self, comptime format: []const u8, args: anytype) Error!void {
            return @errorCast(self.any().print(format, args));
        }

        pub inline fn writeByte(self: Self, byte: u8) Error!void {
            return @errorCast(self.any().writeByte(byte));
        }

        pub inline fn writeByteNTimes(self: Self, byte: u8, n: usize) Error!void {
            return @errorCast(self.any().writeByteNTimes(byte, n));
        }

        pub inline fn writeBytesNTimes(self: Self, bytes: []const u8, n: usize) Error!void {
            return @errorCast(self.any().writeBytesNTimes(bytes, n));
        }

        pub inline fn writeInt(self: Self, comptime T: type, value: T, endian: std.builtin.Endian) Error!void {
            return @errorCast(self.any().writeInt(T, value, endian));
        }

        pub inline fn writeStruct(self: Self, value: anytype) Error!void {
            return @errorCast(self.any().writeStruct(value));
        }

        pub inline fn writeStructEndian(self: Self, value: anytype, endian: std.builtin.Endian) Error!void {
            return @errorCast(self.any().writeStructEndian(value, endian));
        }

        pub inline fn any(self: *const Self) AnyWriter {
            return .{
                .context = @ptrCast(&self.context),
                .writeFn = typeErasedWriteFn,
            };
        }

        fn typeErasedWriteFn(context: *const anyopaque, bytes: []const u8) anyerror!usize {
            const ptr: *const Context = @alignCast(@ptrCast(context));
            return writeFn(ptr.*, bytes);
        }

        /// Helper for bridging to the new `Writer` API while upgrading.
        pub fn adaptToNewApi(self: *const Self) Adapter {
            return .{
                .derp_writer = self.*,
                .new_interface = .{
                    .buffer = &.{},
                    .vtable = &.{ .drain = Adapter.drain },
                },
            };
        }

        pub const Adapter = struct {
            derp_writer: Self,
            new_interface: Writer,
            err: ?Error = null,

            fn drain(w: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
                _ = splat;
                const a: *@This() = @alignCast(@fieldParentPtr("new_interface", w));
                return a.derp_writer.write(data[0]) catch |err| {
                    a.err = err;
                    return error.WriteFailed;
                };
            }
        };
    };
}

/// Deprecated in favor of `Reader`.
pub const AnyReader = @import("Io/DeprecatedReader.zig");
/// Deprecated in favor of `Writer`.
pub const AnyWriter = @import("Io/DeprecatedWriter.zig");

pub const SeekableStream = @import("Io/seekable_stream.zig").SeekableStream;

pub const BufferedWriter = @import("Io/buffered_writer.zig").BufferedWriter;
pub const bufferedWriter = @import("Io/buffered_writer.zig").bufferedWriter;

pub const BufferedReader = @import("Io/buffered_reader.zig").BufferedReader;
pub const bufferedReader = @import("Io/buffered_reader.zig").bufferedReader;
pub const bufferedReaderSize = @import("Io/buffered_reader.zig").bufferedReaderSize;

pub const FixedBufferStream = @import("Io/fixed_buffer_stream.zig").FixedBufferStream;
pub const fixedBufferStream = @import("Io/fixed_buffer_stream.zig").fixedBufferStream;

pub const CWriter = @import("Io/c_writer.zig").CWriter;
pub const cWriter = @import("Io/c_writer.zig").cWriter;

pub const LimitedReader = @import("Io/limited_reader.zig").LimitedReader;
pub const limitedReader = @import("Io/limited_reader.zig").limitedReader;

pub const CountingWriter = @import("Io/counting_writer.zig").CountingWriter;
pub const countingWriter = @import("Io/counting_writer.zig").countingWriter;
pub const CountingReader = @import("Io/counting_reader.zig").CountingReader;
pub const countingReader = @import("Io/counting_reader.zig").countingReader;

pub const MultiWriter = @import("Io/multi_writer.zig").MultiWriter;
pub const multiWriter = @import("Io/multi_writer.zig").multiWriter;

pub const BitReader = @import("Io/bit_reader.zig").BitReader;
pub const bitReader = @import("Io/bit_reader.zig").bitReader;

pub const BitWriter = @import("Io/bit_writer.zig").BitWriter;
pub const bitWriter = @import("Io/bit_writer.zig").bitWriter;

pub const ChangeDetectionStream = @import("Io/change_detection_stream.zig").ChangeDetectionStream;
pub const changeDetectionStream = @import("Io/change_detection_stream.zig").changeDetectionStream;

pub const FindByteWriter = @import("Io/find_byte_writer.zig").FindByteWriter;
pub const findByteWriter = @import("Io/find_byte_writer.zig").findByteWriter;

pub const BufferedAtomicFile = @import("Io/buffered_atomic_file.zig").BufferedAtomicFile;

pub const StreamSource = @import("Io/stream_source.zig").StreamSource;

pub const tty = @import("Io/tty.zig");

/// A Writer that doesn't write to anything.
pub const null_writer: NullWriter = .{ .context = {} };

pub const NullWriter = GenericWriter(void, error{}, dummyWrite);
fn dummyWrite(context: void, data: []const u8) error{}!usize {
    _ = context;
    return data.len;
}

test null_writer {
    null_writer.writeAll("yay" ** 10) catch |err| switch (err) {};
}

pub fn poll(
    allocator: Allocator,
    comptime StreamEnum: type,
    files: PollFiles(StreamEnum),
) Poller(StreamEnum) {
    const enum_fields = @typeInfo(StreamEnum).@"enum".fields;
    var result: Poller(StreamEnum) = undefined;

    if (is_windows) result.windows = .{
        .first_read_done = false,
        .overlapped = [1]windows.OVERLAPPED{
            mem.zeroes(windows.OVERLAPPED),
        } ** enum_fields.len,
        .small_bufs = undefined,
        .active = .{
            .count = 0,
            .handles_buf = undefined,
            .stream_map = undefined,
        },
    };

    inline for (0..enum_fields.len) |i| {
        result.fifos[i] = .{
            .allocator = allocator,
            .buf = &.{},
            .head = 0,
            .count = 0,
        };
        if (is_windows) {
            result.windows.active.handles_buf[i] = @field(files, enum_fields[i].name).handle;
        } else {
            result.poll_fds[i] = .{
                .fd = @field(files, enum_fields[i].name).handle,
                .events = posix.POLL.IN,
                .revents = undefined,
            };
        }
    }
    return result;
}

pub const PollFifo = std.fifo.LinearFifo(u8, .Dynamic);

pub fn Poller(comptime StreamEnum: type) type {
    return struct {
        const enum_fields = @typeInfo(StreamEnum).@"enum".fields;
        const PollFd = if (is_windows) void else posix.pollfd;

        fifos: [enum_fields.len]PollFifo,
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
                    std.debug.assert(index < self.count);
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
            if (is_windows) {
                // cancel any pending IO to prevent clobbering OVERLAPPED value
                for (self.windows.active.handles_buf[0..self.windows.active.count]) |h| {
                    _ = windows.kernel32.CancelIo(h);
                }
            }
            inline for (&self.fifos) |*q| q.deinit();
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

        pub inline fn fifo(self: *Self, comptime which: StreamEnum) *PollFifo {
            return &self.fifos[@intFromEnum(which)];
        }

        fn pollWindows(self: *Self, nanoseconds: ?u64) !bool {
            const bump_amt = 512;

            if (!self.windows.first_read_done) {
                var already_read_data = false;
                for (0..enum_fields.len) |i| {
                    const handle = self.windows.active.handles_buf[i];
                    switch (try windowsAsyncReadToFifoAndQueueSmallRead(
                        handle,
                        &self.windows.overlapped[i],
                        &self.fifos[i],
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
                const stream_fifo = &self.fifos[stream_idx];
                const small_buf = &self.windows.small_bufs[stream_idx];

                const num_bytes_read = switch (try windowsGetReadResult(handle, overlapped, false)) {
                    .success => |n| n,
                    .closed => {
                        self.windows.active.removeAt(active_idx);
                        continue;
                    },
                    .aborted => unreachable,
                };
                try stream_fifo.write(small_buf[0..num_bytes_read]);

                switch (try windowsAsyncReadToFifoAndQueueSmallRead(
                    handle,
                    overlapped,
                    stream_fifo,
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
            inline for (&self.poll_fds, &self.fifos) |*poll_fd, *q| {
                // Try reading whatever is available before checking the error
                // conditions.
                // It's still possible to read after a POLL.HUP is received,
                // always check if there's some data waiting to be read first.
                if (poll_fd.revents & posix.POLL.IN != 0) {
                    const buf = try q.writableWithSize(bump_amt);
                    const amt = posix.read(poll_fd.fd, buf) catch |err| switch (err) {
                        error.BrokenPipe => 0, // Handle the same as EOF.
                        else => |e| return e,
                    };
                    q.update(amt);
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
    };
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
    handle: windows.HANDLE,
    overlapped: *windows.OVERLAPPED,
    fifo: *PollFifo,
    small_buf: *[128]u8,
    bump_amt: usize,
) !enum { empty, populated, closed_populated, closed } {
    var read_any_data = false;
    while (true) {
        const fifo_read_pending = while (true) {
            const buf = try fifo.writableWithSize(bump_amt);
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
            fifo.update(num_bytes_read);

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
            fifo.update(num_bytes_read);
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
        try fifo.write(small_buf[0..num_bytes_read]);
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

/// Given an enum, returns a struct with fields of that enum, each field
/// representing an I/O stream for polling.
pub fn PollFiles(comptime StreamEnum: type) type {
    const enum_fields = @typeInfo(StreamEnum).@"enum".fields;
    var struct_fields: [enum_fields.len]std.builtin.Type.StructField = undefined;
    for (&struct_fields, enum_fields) |*struct_field, enum_field| {
        struct_field.* = .{
            .name = enum_field.name,
            .type = fs.File,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(fs.File),
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
    _ = Reader.Limited;
    _ = Writer;
    _ = @import("Io/bit_reader.zig");
    _ = @import("Io/bit_writer.zig");
    _ = @import("Io/buffered_atomic_file.zig");
    _ = @import("Io/buffered_reader.zig");
    _ = @import("Io/buffered_writer.zig");
    _ = @import("Io/c_writer.zig");
    _ = @import("Io/counting_writer.zig");
    _ = @import("Io/counting_reader.zig");
    _ = @import("Io/fixed_buffer_stream.zig");
    _ = @import("Io/seekable_stream.zig");
    _ = @import("Io/stream_source.zig");
    _ = @import("Io/test.zig");
}

const Io = @This();

pub const EventLoop = @import("Io/EventLoop.zig");
pub const ThreadPool = @import("Io/ThreadPool.zig");

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
    /// Thread-safe.
    asyncConcurrent: *const fn (
        /// Corresponds to `Io.userdata`.
        userdata: ?*anyopaque,
        result_len: usize,
        result_alignment: std.mem.Alignment,
        /// Copied and then passed to `start`.
        context: []const u8,
        context_alignment: std.mem.Alignment,
        start: *const fn (context: *const anyopaque, result: *anyopaque) void,
    ) error{OutOfMemory}!*AnyFuture,
    /// Executes `start` asynchronously in a manner such that it cleans itself
    /// up. This mode does not support results, await, or cancel.
    ///
    /// Thread-safe.
    asyncDetached: *const fn (
        /// Corresponds to `Io.userdata`.
        userdata: ?*anyopaque,
        /// Copied and then passed to `start`.
        context: []const u8,
        context_alignment: std.mem.Alignment,
        start: *const fn (context: *const anyopaque) void,
    ) void,
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

    /// Blocks until one of the futures from the list has a result ready, such
    /// that awaiting it will not block. Returns that index.
    select: *const fn (?*anyopaque, futures: []const *AnyFuture) usize,

    mutexLock: *const fn (?*anyopaque, prev_state: Mutex.State, mutex: *Mutex) Cancelable!void,
    mutexUnlock: *const fn (?*anyopaque, prev_state: Mutex.State, mutex: *Mutex) void,

    conditionWait: *const fn (?*anyopaque, cond: *Condition, mutex: *Mutex) Cancelable!void,
    conditionWake: *const fn (?*anyopaque, cond: *Condition, wake: Condition.Wake) void,

    createFile: *const fn (?*anyopaque, dir: Dir, sub_path: []const u8, flags: File.CreateFlags) File.OpenError!File,
    openFile: *const fn (?*anyopaque, dir: Dir, sub_path: []const u8, flags: File.OpenFlags) File.OpenError!File,
    closeFile: *const fn (?*anyopaque, File) void,
    pread: *const fn (?*anyopaque, file: File, buffer: []u8, offset: std.posix.off_t) File.PReadError!usize,
    pwrite: *const fn (?*anyopaque, file: File, buffer: []const u8, offset: std.posix.off_t) File.PWriteError!usize,

    now: *const fn (?*anyopaque, clockid: std.posix.clockid_t) ClockGetTimeError!Timestamp,
    sleep: *const fn (?*anyopaque, clockid: std.posix.clockid_t, deadline: Deadline) SleepError!void,
};

pub const Cancelable = error{
    /// Caller has requested the async operation to stop.
    Canceled,
};

pub const Dir = struct {
    handle: Handle,

    pub fn cwd() Dir {
        return .{ .handle = std.fs.cwd().fd };
    }

    pub const Handle = std.posix.fd_t;

    pub fn openFile(dir: Dir, io: Io, sub_path: []const u8, flags: File.OpenFlags) File.OpenError!File {
        return io.vtable.openFile(io.userdata, dir, sub_path, flags);
    }

    pub fn createFile(dir: Dir, io: Io, sub_path: []const u8, flags: File.CreateFlags) File.OpenError!File {
        return io.vtable.createFile(io.userdata, dir, sub_path, flags);
    }

    pub const WriteFileOptions = struct {
        /// On Windows, `sub_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
        /// On WASI, `sub_path` should be encoded as valid UTF-8.
        /// On other platforms, `sub_path` is an opaque sequence of bytes with no particular encoding.
        sub_path: []const u8,
        data: []const u8,
        flags: File.CreateFlags = .{},
    };

    pub const WriteFileError = File.WriteError || File.OpenError || Cancelable;

    /// Writes content to the file system, using the file creation flags provided.
    pub fn writeFile(dir: Dir, io: Io, options: WriteFileOptions) WriteFileError!void {
        var file = try dir.createFile(io, options.sub_path, options.flags);
        defer file.close(io);
        try file.writeAll(io, options.data);
    }
};

pub const File = struct {
    handle: Handle,

    pub const Handle = std.posix.fd_t;

    pub const OpenFlags = fs.File.OpenFlags;
    pub const CreateFlags = fs.File.CreateFlags;

    pub const OpenError = fs.File.OpenError || Cancelable;

    pub fn close(file: File, io: Io) void {
        return io.vtable.closeFile(io.userdata, file);
    }

    pub const ReadError = fs.File.ReadError || Cancelable;

    pub fn read(file: File, io: Io, buffer: []u8) ReadError!usize {
        return @errorCast(file.pread(io, buffer, -1));
    }

    pub const PReadError = fs.File.PReadError || Cancelable;

    pub fn pread(file: File, io: Io, buffer: []u8, offset: std.posix.off_t) PReadError!usize {
        return io.vtable.pread(io.userdata, file, buffer, offset);
    }

    pub const WriteError = fs.File.WriteError || Cancelable;

    pub fn write(file: File, io: Io, buffer: []const u8) WriteError!usize {
        return @errorCast(file.pwrite(io, buffer, -1));
    }

    pub const PWriteError = fs.File.PWriteError || Cancelable;

    pub fn pwrite(file: File, io: Io, buffer: []const u8, offset: std.posix.off_t) PWriteError!usize {
        return io.vtable.pwrite(io.userdata, file, buffer, offset);
    }

    pub fn writeAll(file: File, io: Io, bytes: []const u8) WriteError!void {
        var index: usize = 0;
        while (index < bytes.len) {
            index += try file.write(io, bytes[index..]);
        }
    }

    pub fn readAll(file: File, io: Io, buffer: []u8) ReadError!usize {
        var index: usize = 0;
        while (index != buffer.len) {
            const amt = try file.read(io, buffer[index..]);
            if (amt == 0) break;
            index += amt;
        }
        return index;
    }
};

pub const Timestamp = enum(i96) {
    _,

    pub fn durationTo(from: Timestamp, to: Timestamp) Duration {
        return .{ .nanoseconds = @intFromEnum(to) - @intFromEnum(from) };
    }

    pub fn addDuration(from: Timestamp, duration: Duration) Timestamp {
        return @enumFromInt(@intFromEnum(from) + duration.nanoseconds);
    }
};
pub const Duration = struct {
    nanoseconds: i96,

    pub fn ms(x: u64) Duration {
        return .{ .nanoseconds = @as(i96, x) * std.time.ns_per_ms };
    }
};
pub const Deadline = union(enum) {
    duration: Duration,
    timestamp: Timestamp,
};
pub const ClockGetTimeError = std.posix.ClockGetTimeError || Cancelable;
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

pub const Mutex = if (true) struct {
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

    pub fn unlock(mutex: *Mutex, io: std.Io) void {
        const prev_state = @cmpxchgWeak(State, &mutex.state, .locked_once, .unlocked, .release, .acquire) orelse {
            @branchHint(.likely);
            return;
        };
        std.debug.assert(prev_state != .unlocked); // mutex not locked
        return io.vtable.mutexUnlock(io.userdata, prev_state, mutex);
    }
} else struct {
    state: std.atomic.Value(u32),

    pub const State = void;

    pub const init: Mutex = .{ .state = .init(unlocked) };

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
    pub fn lock(m: *Mutex, io: Io) Cancelable!void {
        if (!m.tryLock()) {
            @branchHint(.unlikely);
            try io.vtable.mutexLock(io.userdata, {}, m);
        }
    }

    pub fn unlock(m: *Mutex, io: Io) void {
        io.vtable.mutexUnlock(io.userdata, {}, m);
    }
};

/// Supports exactly 1 waiter. More than 1 simultaneous wait on the same
/// condition is illegal.
pub const Condition = struct {
    state: u64 = 0,

    pub fn wait(cond: *Condition, io: Io, mutex: *Mutex) Cancelable!void {
        return io.vtable.conditionWait(io.userdata, cond, mutex);
    }

    pub fn signal(cond: *Condition, io: Io) void {
        io.vtable.conditionWake(io.userdata, cond, .one);
    }

    pub fn broadcast(cond: *Condition, io: Io) void {
        io.vtable.conditionWake(io.userdata, cond, .all);
    }

    pub const Wake = enum {
        /// wake up only one thread
        one,
        /// wake up all thread
        all,
    };
};

pub const TypeErasedQueue = struct {
    mutex: Mutex,

    /// Ring buffer. This data is logically *after* queued getters.
    buffer: []u8,
    put_index: usize,
    get_index: usize,

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
            .put_index = 0,
            .get_index = 0,
            .putters = .{},
            .getters = .{},
        };
    }

    pub fn put(q: *TypeErasedQueue, io: Io, elements: []const u8, min: usize) Cancelable!usize {
        assert(elements.len >= min);

        try q.mutex.lock(io);
        defer q.mutex.unlock(io);

        // Getters have first priority on the data, and only when the getters
        // queue is empty do we start populating the buffer.

        var remaining = elements;
        while (true) {
            const getter: *Get = @fieldParentPtr("node", q.getters.popFirst() orelse break);
            const copy_len = @min(getter.remaining.len, remaining.len);
            @memcpy(getter.remaining[0..copy_len], remaining[0..copy_len]);
            remaining = remaining[copy_len..];
            getter.remaining = getter.remaining[copy_len..];
            if (getter.remaining.len == 0) {
                getter.condition.signal(io);
                continue;
            }
            q.getters.prepend(&getter.node);
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

            var pending: Put = .{ .remaining = remaining, .condition = .{}, .node = .{} };
            q.putters.append(&pending.node);
            try pending.condition.wait(io, &q.mutex);
            remaining = pending.remaining;
        }
    }

    pub fn get(q: *@This(), io: Io, buffer: []u8, min: usize) Cancelable!usize {
        assert(buffer.len >= min);

        try q.mutex.lock(io);
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
                const putter: *Put = @fieldParentPtr("node", q.putters.popFirst() orelse break);
                const copy_len = @min(putter.remaining.len, remaining.len);
                @memcpy(remaining[0..copy_len], putter.remaining[0..copy_len]);
                putter.remaining = putter.remaining[copy_len..];
                remaining = remaining[copy_len..];
                if (putter.remaining.len == 0) {
                    putter.condition.signal(io);
                } else {
                    assert(remaining.len == 0);
                    q.putters.prepend(&putter.node);
                    return fillRingBufferFromPutters(q, io, buffer.len);
                }
            }
            // Both ring buffer and putters queue is empty.
            const total_filled = buffer.len - remaining.len;
            if (total_filled >= min) return total_filled;

            var pending: Get = .{ .remaining = remaining, .condition = .{}, .node = .{} };
            q.getters.append(&pending.node);
            try pending.condition.wait(io, &q.mutex);
            remaining = pending.remaining;
        }
    }

    /// Called when there is nonzero space available in the ring buffer and
    /// potentially putters waiting. The mutex is already held and the task is
    /// to copy putter data to the ring buffer and signal any putters whose
    /// buffers been fully copied.
    fn fillRingBufferFromPutters(q: *TypeErasedQueue, io: Io, len: usize) usize {
        while (true) {
            const putter: *Put = @fieldParentPtr("node", q.putters.popFirst() orelse return len);
            const available = q.buffer[q.put_index..];
            const copy_len = @min(available.len, putter.remaining.len);
            @memcpy(available[0..copy_len], putter.remaining[0..copy_len]);
            putter.remaining = putter.remaining[copy_len..];
            q.put_index += copy_len;
            if (putter.remaining.len == 0) {
                putter.condition.signal(io);
                continue;
            }
            const second_available = q.buffer[0..q.get_index];
            const second_copy_len = @min(second_available.len, putter.remaining.len);
            @memcpy(second_available[0..second_copy_len], putter.remaining[0..second_copy_len]);
            putter.remaining = putter.remaining[copy_len..];
            q.put_index = copy_len;
            if (putter.remaining.len == 0) {
                putter.condition.signal(io);
                continue;
            }
            q.putters.prepend(&putter.node);
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
        pub fn put(q: *@This(), io: Io, elements: []const Elem, min: usize) Cancelable!usize {
            return @divExact(try q.type_erased.put(io, @ptrCast(elements), min * @sizeOf(Elem)), @sizeOf(Elem));
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

        pub fn putOne(q: *@This(), io: Io, item: Elem) Cancelable!void {
            assert(try q.put(io, &.{item}, 1) == 1);
        }

        pub fn getOne(q: *@This(), io: Io) Cancelable!Elem {
            var buf: [1]Elem = undefined;
            assert(try q.get(io, &buf, 1) == 1);
            return buf[0];
        }
    };
}

/// Calls `function` with `args`, such that the return value of the function is
/// not guaranteed to be available until `await` is called.
///
/// `function` *may* be called immediately, before `async` returns. This has
/// weaker guarantees than `asyncConcurrent`, making more portable and
/// reusable.
///
/// See also:
/// * `asyncDetached`
pub fn async(
    io: Io,
    function: anytype,
    args: std.meta.ArgsTuple(@TypeOf(function)),
) Future(@typeInfo(@TypeOf(function)).@"fn".return_type.?) {
    const Result = @typeInfo(@TypeOf(function)).@"fn".return_type.?;
    const Args = @TypeOf(args);
    const TypeErased = struct {
        fn start(context: *const anyopaque, result: *anyopaque) void {
            const args_casted: *const Args = @alignCast(@ptrCast(context));
            const result_casted: *Result = @ptrCast(@alignCast(result));
            result_casted.* = @call(.auto, function, args_casted.*);
        }
    };
    var future: Future(Result) = undefined;
    future.any_future = io.vtable.async(
        io.userdata,
        @ptrCast((&future.result)[0..1]),
        .of(Result),
        @ptrCast((&args)[0..1]),
        .of(Args),
        TypeErased.start,
    );
    return future;
}

/// Calls `function` with `args`, such that the return value of the function is
/// not guaranteed to be available until `await` is called, allowing the caller
/// to progress while waiting for any `Io` operations.
///
/// This has stronger guarantee than `async`, placing restrictions on what kind
/// of `Io` implementations are supported. By calling `async` instead, one
/// allows, for example, stackful single-threaded blocking I/O.
pub fn asyncConcurrent(
    io: Io,
    function: anytype,
    args: std.meta.ArgsTuple(@TypeOf(function)),
) error{OutOfMemory}!Future(@typeInfo(@TypeOf(function)).@"fn".return_type.?) {
    const Result = @typeInfo(@TypeOf(function)).@"fn".return_type.?;
    const Args = @TypeOf(args);
    const TypeErased = struct {
        fn start(context: *const anyopaque, result: *anyopaque) void {
            const args_casted: *const Args = @alignCast(@ptrCast(context));
            const result_casted: *Result = @ptrCast(@alignCast(result));
            result_casted.* = @call(.auto, function, args_casted.*);
        }
    };
    var future: Future(Result) = undefined;
    future.any_future = try io.vtable.asyncConcurrent(
        io.userdata,
        @sizeOf(Result),
        .of(Result),
        @ptrCast((&args)[0..1]),
        .of(Args),
        TypeErased.start,
    );
    return future;
}

/// Calls `function` with `args` asynchronously. The resource cleans itself up
/// when the function returns. Does not support await, cancel, or a return value.
///
/// `function` *may* be called immediately, before `async` returns.
///
/// See also:
/// * `async`
/// * `asyncConcurrent`
pub fn asyncDetached(io: Io, function: anytype, args: std.meta.ArgsTuple(@TypeOf(function))) void {
    const Args = @TypeOf(args);
    const TypeErased = struct {
        fn start(context: *const anyopaque) void {
            const args_casted: *const Args = @alignCast(@ptrCast(context));
            @call(.auto, function, args_casted.*);
        }
    };
    io.vtable.asyncDetached(io.userdata, @ptrCast((&args)[0..1]), .of(Args), TypeErased.start);
}

pub fn cancelRequested(io: Io) bool {
    return io.vtable.cancelRequested(io.userdata);
}

pub fn now(io: Io, clockid: std.posix.clockid_t) ClockGetTimeError!Timestamp {
    return io.vtable.now(io.userdata, clockid);
}

pub fn sleep(io: Io, clockid: std.posix.clockid_t, deadline: Deadline) SleepError!void {
    return io.vtable.sleep(io.userdata, clockid, deadline);
}

pub fn sleepDuration(io: Io, duration: Duration) SleepError!void {
    return io.vtable.sleep(io.userdata, .MONOTONIC, .{ .duration = duration });
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
pub fn select(io: Io, s: anytype) SelectUnion(@TypeOf(s)) {
    const U = SelectUnion(@TypeOf(s));
    const S = @TypeOf(s);
    const fields = @typeInfo(S).@"struct".fields;
    var futures: [fields.len]*AnyFuture = undefined;
    inline for (fields, &futures) |field, *any_future| {
        const future = @field(s, field.name);
        any_future.* = future.any_future orelse return @unionInit(U, field.name, future.result);
    }
    switch (io.vtable.select(io.userdata, &futures)) {
        inline 0...(fields.len - 1) => |selected_index| {
            const field_name = fields[selected_index].name;
            return @unionInit(U, field_name, @field(s, field_name).await(io));
        },
        else => unreachable,
    }
}
