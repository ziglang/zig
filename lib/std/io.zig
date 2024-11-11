const std = @import("std.zig");
const builtin = @import("builtin");
const root = @import("root");
const c = std.c;
const is_windows = builtin.os.tag == .windows;
const windows = std.os.windows;
const posix = std.posix;

const math = std.math;
const assert = std.debug.assert;
const fs = std.fs;
const mem = std.mem;
const meta = std.meta;
const File = std.fs.File;
const Allocator = std.mem.Allocator;

fn getStdOutHandle() posix.fd_t {
    if (is_windows) {
        if (builtin.zig_backend == .stage2_aarch64) {
            // TODO: this is just a temporary workaround until we advance aarch64 backend further along.
            return windows.GetStdHandle(windows.STD_OUTPUT_HANDLE) catch windows.INVALID_HANDLE_VALUE;
        }
        return windows.peb().ProcessParameters.hStdOutput;
    }

    if (@hasDecl(root, "os") and @hasDecl(root.os, "io") and @hasDecl(root.os.io, "getStdOutHandle")) {
        return root.os.io.getStdOutHandle();
    }

    return posix.STDOUT_FILENO;
}

pub fn getStdOut() File {
    return .{ .handle = getStdOutHandle() };
}

fn getStdErrHandle() posix.fd_t {
    if (is_windows) {
        if (builtin.zig_backend == .stage2_aarch64) {
            // TODO: this is just a temporary workaround until we advance aarch64 backend further along.
            return windows.GetStdHandle(windows.STD_ERROR_HANDLE) catch windows.INVALID_HANDLE_VALUE;
        }
        return windows.peb().ProcessParameters.hStdError;
    }

    if (@hasDecl(root, "os") and @hasDecl(root.os, "io") and @hasDecl(root.os.io, "getStdErrHandle")) {
        return root.os.io.getStdErrHandle();
    }

    return posix.STDERR_FILENO;
}

pub fn getStdErr() File {
    return .{ .handle = getStdErrHandle() };
}

fn getStdInHandle() posix.fd_t {
    if (is_windows) {
        if (builtin.zig_backend == .stage2_aarch64) {
            // TODO: this is just a temporary workaround until we advance aarch64 backend further along.
            return windows.GetStdHandle(windows.STD_INPUT_HANDLE) catch windows.INVALID_HANDLE_VALUE;
        }
        return windows.peb().ProcessParameters.hStdInput;
    }

    if (@hasDecl(root, "os") and @hasDecl(root.os, "io") and @hasDecl(root.os.io, "getStdInHandle")) {
        return root.os.io.getStdInHandle();
    }

    return posix.STDIN_FILENO;
}

pub fn getStdIn() File {
    return .{ .handle = getStdInHandle() };
}

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
            comptime alignment: ?u29,
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
    };
}

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
    };
}

/// Deprecated; consider switching to `AnyReader` or use `GenericReader`
/// to use previous API.
pub const Reader = GenericReader;
/// Deprecated; consider switching to `AnyWriter` or use `GenericWriter`
/// to use previous API.
pub const Writer = GenericWriter;

pub const AnyReader = @import("io/Reader.zig");
pub const AnyWriter = @import("io/Writer.zig");

pub const SeekableStream = @import("io/seekable_stream.zig").SeekableStream;

pub const BufferedWriter = @import("io/buffered_writer.zig").BufferedWriter;
pub const bufferedWriter = @import("io/buffered_writer.zig").bufferedWriter;

pub const BufferedReader = @import("io/buffered_reader.zig").BufferedReader;
pub const bufferedReader = @import("io/buffered_reader.zig").bufferedReader;
pub const bufferedReaderSize = @import("io/buffered_reader.zig").bufferedReaderSize;

pub const FixedBufferStream = @import("io/fixed_buffer_stream.zig").FixedBufferStream;
pub const fixedBufferStream = @import("io/fixed_buffer_stream.zig").fixedBufferStream;

pub const CWriter = @import("io/c_writer.zig").CWriter;
pub const cWriter = @import("io/c_writer.zig").cWriter;

pub const LimitedReader = @import("io/limited_reader.zig").LimitedReader;
pub const limitedReader = @import("io/limited_reader.zig").limitedReader;

pub const CountingWriter = @import("io/counting_writer.zig").CountingWriter;
pub const countingWriter = @import("io/counting_writer.zig").countingWriter;
pub const CountingReader = @import("io/counting_reader.zig").CountingReader;
pub const countingReader = @import("io/counting_reader.zig").countingReader;

pub const MultiWriter = @import("io/multi_writer.zig").MultiWriter;
pub const multiWriter = @import("io/multi_writer.zig").multiWriter;

pub const BitReader = @import("io/bit_reader.zig").BitReader;
pub const bitReader = @import("io/bit_reader.zig").bitReader;

pub const BitWriter = @import("io/bit_writer.zig").BitWriter;
pub const bitWriter = @import("io/bit_writer.zig").bitWriter;

pub const ChangeDetectionStream = @import("io/change_detection_stream.zig").ChangeDetectionStream;
pub const changeDetectionStream = @import("io/change_detection_stream.zig").changeDetectionStream;

pub const FindByteWriter = @import("io/find_byte_writer.zig").FindByteWriter;
pub const findByteWriter = @import("io/find_byte_writer.zig").findByteWriter;

pub const BufferedAtomicFile = @import("io/buffered_atomic_file.zig").BufferedAtomicFile;

pub const StreamSource = @import("io/stream_source.zig").StreamSource;

pub const tty = @import("io/tty.zig");

/// A Writer that doesn't write to anything.
pub const null_writer: NullWriter = .{ .context = {} };

pub const NullWriter = Writer(void, error{}, dummyWrite);
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
                    const amt = try posix.read(poll_fd.fd, buf);
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
            .name = enum_field.name ++ "",
            .type = fs.File,
            .default_value = null,
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
    _ = AnyReader;
    _ = AnyWriter;
    _ = @import("io/bit_reader.zig");
    _ = @import("io/bit_writer.zig");
    _ = @import("io/buffered_atomic_file.zig");
    _ = @import("io/buffered_reader.zig");
    _ = @import("io/buffered_writer.zig");
    _ = @import("io/c_writer.zig");
    _ = @import("io/counting_writer.zig");
    _ = @import("io/counting_reader.zig");
    _ = @import("io/fixed_buffer_stream.zig");
    _ = @import("io/seekable_stream.zig");
    _ = @import("io/stream_source.zig");
    _ = @import("io/test.zig");
}
