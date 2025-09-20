const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();

const Writer = @This();
const std = @import("../std.zig");
const assert = std.debug.assert;
const Limit = std.Io.Limit;
const File = std.fs.File;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

vtable: *const VTable,
/// If this has length zero, the writer is unbuffered, and `flush` is a no-op.
buffer: []u8,
/// In `buffer` before this are buffered bytes, after this is `undefined`.
end: usize = 0,

pub const VTable = struct {
    /// Sends bytes to the logical sink. A write will only be sent here if it
    /// could not fit into `buffer`, or during a `flush` operation.
    ///
    /// `buffer[0..end]` is consumed first, followed by each slice of `data` in
    /// order. Elements of `data` may alias each other but may not alias
    /// `buffer`.
    ///
    /// This function modifies `Writer.end` and `Writer.buffer` in an
    /// implementation-defined manner.
    ///
    /// `data.len` must be nonzero.
    ///
    /// The last element of `data` is repeated as necessary so that it is
    /// written `splat` number of times, which may be zero.
    ///
    /// This function may not be called if the data to be written could have
    /// been stored in `buffer` instead, including when the amount of data to
    /// be written is zero and the buffer capacity is zero.
    ///
    /// Number of bytes consumed from `data` is returned, excluding bytes from
    /// `buffer`.
    ///
    /// Number of bytes returned may be zero, which does not indicate stream
    /// end. A subsequent call may return nonzero, or signal end of stream via
    /// `error.WriteFailed`.
    drain: *const fn (w: *Writer, data: []const []const u8, splat: usize) Error!usize,

    /// Copies contents from an open file to the logical sink. `buffer[0..end]`
    /// is consumed first, followed by `limit` bytes from `file_reader`.
    ///
    /// Number of bytes logically written is returned. This excludes bytes from
    /// `buffer` because they have already been logically written. Number of
    /// bytes consumed from `buffer` are tracked by modifying `end`.
    ///
    /// Number of bytes returned may be zero, which does not indicate stream
    /// end. A subsequent call may return nonzero, or signal end of stream via
    /// `error.WriteFailed`. Caller may check `file_reader` state
    /// (`File.Reader.atEnd`) to disambiguate between a zero-length read or
    /// write, and whether the file reached the end.
    ///
    /// `error.Unimplemented` indicates the callee cannot offer a more
    /// efficient implementation than the caller performing its own reads.
    sendFile: *const fn (
        w: *Writer,
        file_reader: *File.Reader,
        /// Maximum amount of bytes to read from the file. Implementations may
        /// assume that the file size does not exceed this amount. Data from
        /// `buffer` does not count towards this limit.
        limit: Limit,
    ) FileError!usize = unimplementedSendFile,

    /// Consumes all remaining buffer.
    ///
    /// The default flush implementation calls drain repeatedly until `end` is
    /// zero, however it is legal for implementations to manage `end`
    /// differently. For instance, `Allocating` flush is a no-op.
    ///
    /// There may be subsequent calls to `drain` and `sendFile` after a `flush`
    /// operation.
    flush: *const fn (w: *Writer) Error!void = defaultFlush,

    /// Ensures `capacity` more bytes can be buffered without rebasing.
    ///
    /// The most recent `preserve` bytes must remain buffered.
    ///
    /// Only called when `capacity` bytes cannot fit into the unused capacity
    /// of `buffer`.
    rebase: *const fn (w: *Writer, preserve: usize, capacity: usize) Error!void = defaultRebase,
};

pub const Error = error{
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
};

pub const FileAllError = error{
    /// Detailed diagnostics are found on the `File.Reader` struct.
    ReadFailed,
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
};

pub const FileReadingError = error{
    /// Detailed diagnostics are found on the `File.Reader` struct.
    ReadFailed,
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
    /// Reached the end of the file being read.
    EndOfStream,
};

pub const FileError = error{
    /// Detailed diagnostics are found on the `File.Reader` struct.
    ReadFailed,
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
    /// Reached the end of the file being read.
    EndOfStream,
    /// Indicates the caller should do its own file reading; the callee cannot
    /// offer a more efficient implementation.
    Unimplemented,
};

/// Writes to `buffer` and returns `error.WriteFailed` when it is full.
pub fn fixed(buffer: []u8) Writer {
    return .{
        .vtable = &.{
            .drain = fixedDrain,
            .flush = noopFlush,
            .rebase = failingRebase,
        },
        .buffer = buffer,
    };
}

pub fn hashed(w: *Writer, hasher: anytype, buffer: []u8) Hashed(@TypeOf(hasher)) {
    return .initHasher(w, hasher, buffer);
}

pub const failing: Writer = .{
    .vtable = &.{
        .drain = failingDrain,
        .sendFile = failingSendFile,
        .rebase = failingRebase,
    },
    .buffer = &.{},
};

test failing {
    var fw: Writer = .failing;
    try testing.expectError(error.WriteFailed, fw.writeAll("always fails"));
}

/// Returns the contents not yet drained.
pub fn buffered(w: *const Writer) []u8 {
    return w.buffer[0..w.end];
}

pub fn countSplat(data: []const []const u8, splat: usize) usize {
    var total: usize = 0;
    for (data[0 .. data.len - 1]) |buf| total += buf.len;
    total += data[data.len - 1].len * splat;
    return total;
}

pub fn countSendFileLowerBound(n: usize, file_reader: *File.Reader, limit: Limit) ?usize {
    const total: u64 = @min(@intFromEnum(limit), file_reader.getSize() catch return null);
    return std.math.lossyCast(usize, total + n);
}

/// If the total number of bytes of `data` fits inside `unusedCapacitySlice`,
/// this function is guaranteed to not fail, not call into `VTable`, and return
/// the total bytes inside `data`.
pub fn writeVec(w: *Writer, data: []const []const u8) Error!usize {
    return writeSplat(w, data, 1);
}

/// If the number of bytes to write based on `data` and `splat` fits inside
/// `unusedCapacitySlice`, this function is guaranteed to not fail, not call
/// into `VTable`, and return the full number of bytes.
pub fn writeSplat(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
    assert(data.len > 0);
    const buffer = w.buffer;
    const count = countSplat(data, splat);
    if (w.end + count > buffer.len) return w.vtable.drain(w, data, splat);
    for (data[0 .. data.len - 1]) |bytes| {
        @memcpy(buffer[w.end..][0..bytes.len], bytes);
        w.end += bytes.len;
    }
    const pattern = data[data.len - 1];
    switch (pattern.len) {
        0 => {},
        1 => {
            @memset(buffer[w.end..][0..splat], pattern[0]);
            w.end += splat;
        },
        else => for (0..splat) |_| {
            @memcpy(buffer[w.end..][0..pattern.len], pattern);
            w.end += pattern.len;
        },
    }
    return count;
}

/// Returns how many bytes were consumed from `header` and `data`.
pub fn writeSplatHeader(
    w: *Writer,
    header: []const u8,
    data: []const []const u8,
    splat: usize,
) Error!usize {
    return writeSplatHeaderLimit(w, header, data, splat, .unlimited);
}

/// Equivalent to `writeSplatHeader` but writes at most `limit` bytes.
pub fn writeSplatHeaderLimit(
    w: *Writer,
    header: []const u8,
    data: []const []const u8,
    splat: usize,
    limit: Limit,
) Error!usize {
    var remaining = @intFromEnum(limit);
    {
        const copy_len = @min(header.len, w.buffer.len - w.end, remaining);
        if (header.len - copy_len != 0) return writeSplatHeaderLimitFinish(w, header, data, splat, remaining);
        @memcpy(w.buffer[w.end..][0..copy_len], header[0..copy_len]);
        w.end += copy_len;
        remaining -= copy_len;
    }
    for (data[0 .. data.len - 1], 0..) |buf, i| {
        const copy_len = @min(buf.len, w.buffer.len - w.end, remaining);
        if (buf.len - copy_len != 0) return @intFromEnum(limit) - remaining +
            try writeSplatHeaderLimitFinish(w, &.{}, data[i..], splat, remaining);
        @memcpy(w.buffer[w.end..][0..copy_len], buf[0..copy_len]);
        w.end += copy_len;
        remaining -= copy_len;
    }
    const pattern = data[data.len - 1];
    const splat_n = pattern.len * splat;
    if (splat_n > @min(w.buffer.len - w.end, remaining)) {
        const buffered_n = @intFromEnum(limit) - remaining;
        const written = try writeSplatHeaderLimitFinish(w, &.{}, data[data.len - 1 ..][0..1], splat, remaining);
        return buffered_n + written;
    }

    for (0..splat) |_| {
        @memcpy(w.buffer[w.end..][0..pattern.len], pattern);
        w.end += pattern.len;
    }

    remaining -= splat_n;
    return @intFromEnum(limit) - remaining;
}

fn writeSplatHeaderLimitFinish(
    w: *Writer,
    header: []const u8,
    data: []const []const u8,
    splat: usize,
    limit: usize,
) Error!usize {
    var remaining = limit;
    var vecs: [8][]const u8 = undefined;
    var i: usize = 0;
    v: {
        if (header.len != 0) {
            const copy_len = @min(header.len, remaining);
            vecs[i] = header[0..copy_len];
            i += 1;
            remaining -= copy_len;
            if (remaining == 0) break :v;
        }
        for (data[0 .. data.len - 1]) |buf| if (buf.len != 0) {
            const copy_len = @min(header.len, remaining);
            vecs[i] = buf;
            i += 1;
            remaining -= copy_len;
            if (remaining == 0) break :v;
            if (vecs.len - i == 0) break :v;
        };
        const pattern = data[data.len - 1];
        if (splat == 1) {
            vecs[i] = pattern[0..@min(remaining, pattern.len)];
            i += 1;
            break :v;
        }
        vecs[i] = pattern;
        i += 1;
        return w.vtable.drain(w, (&vecs)[0..i], @min(remaining / pattern.len, splat));
    }
    return w.vtable.drain(w, (&vecs)[0..i], 1);
}

test "writeSplatHeader splatting avoids buffer aliasing temptation" {
    const initial_buf = try testing.allocator.alloc(u8, 8);
    var aw: Allocating = .initOwnedSlice(testing.allocator, initial_buf);
    defer aw.deinit();
    // This test assumes 8 vector buffer in this function.
    const n = try aw.writer.writeSplatHeader("header which is longer than buf ", &.{
        "1", "2", "3", "4", "5", "6", "foo", "bar", "foo",
    }, 3);
    try testing.expectEqual(41, n);
    try testing.expectEqualStrings(
        "header which is longer than buf 123456foo",
        aw.writer.buffered(),
    );
}

/// Drains all remaining buffered data.
pub fn flush(w: *Writer) Error!void {
    return w.vtable.flush(w);
}

/// Repeatedly calls `VTable.drain` until `end` is zero.
pub fn defaultFlush(w: *Writer) Error!void {
    const drainFn = w.vtable.drain;
    while (w.end != 0) _ = try drainFn(w, &.{""}, 1);
}

/// Does nothing.
pub fn noopFlush(w: *Writer) Error!void {
    _ = w;
}

test "fixed buffer flush" {
    var buffer: [1]u8 = undefined;
    var writer: Writer = .fixed(&buffer);

    try writer.writeByte(10);
    try writer.flush();
    try testing.expectEqual(10, buffer[0]);
}

pub fn rebase(w: *Writer, preserve: usize, unused_capacity_len: usize) Error!void {
    if (w.buffer.len - w.end >= unused_capacity_len) {
        @branchHint(.likely);
        return;
    }
    return w.vtable.rebase(w, preserve, unused_capacity_len);
}

pub fn defaultRebase(w: *Writer, preserve: usize, minimum_len: usize) Error!void {
    while (w.buffer.len - w.end < minimum_len) {
        {
            // TODO: instead of this logic that "hides" data from
            // the implementation, introduce a seek index to Writer
            const preserved_head = w.end -| preserve;
            const preserved_tail = w.end;
            const preserved_len = preserved_tail - preserved_head;
            w.end = preserved_head;
            defer w.end += preserved_len;
            assert(0 == try w.vtable.drain(w, &.{""}, 1));
            assert(w.end <= preserved_head + preserved_len);
            @memmove(w.buffer[w.end..][0..preserved_len], w.buffer[preserved_head..preserved_tail]);
        }

        // If the loop condition was false this assertion would have passed
        // anyway. Otherwise, give the implementation a chance to grow the
        // buffer before asserting on the buffer length.
        assert(w.buffer.len - preserve >= minimum_len);
    }
}

pub fn unusedCapacitySlice(w: *const Writer) []u8 {
    return w.buffer[w.end..];
}

pub fn unusedCapacityLen(w: *const Writer) usize {
    return w.buffer.len - w.end;
}

/// Asserts the provided buffer has total capacity enough for `len`.
///
/// Advances the buffer end position by `len`.
pub fn writableArray(w: *Writer, comptime len: usize) Error!*[len]u8 {
    const big_slice = try w.writableSliceGreedy(len);
    advance(w, len);
    return big_slice[0..len];
}

/// Asserts the provided buffer has total capacity enough for `len`.
///
/// Advances the buffer end position by `len`.
pub fn writableSlice(w: *Writer, len: usize) Error![]u8 {
    const big_slice = try w.writableSliceGreedy(len);
    advance(w, len);
    return big_slice[0..len];
}

/// Asserts the provided buffer has total capacity enough for `minimum_len`.
///
/// Does not `advance` the buffer end position.
///
/// If `minimum_len` is zero, this is equivalent to `unusedCapacitySlice`.
pub fn writableSliceGreedy(w: *Writer, minimum_len: usize) Error![]u8 {
    return writableSliceGreedyPreserve(w, 0, minimum_len);
}

/// Asserts the provided buffer has total capacity enough for `minimum_len`
/// and `preserve` combined.
///
/// Does not `advance` the buffer end position.
///
/// When draining the buffer, ensures that at least `preserve` bytes
/// remain buffered.
///
/// If `preserve` is zero, this is equivalent to `writableSliceGreedy`.
pub fn writableSliceGreedyPreserve(w: *Writer, preserve: usize, minimum_len: usize) Error![]u8 {
    if (w.buffer.len - w.end >= minimum_len) {
        @branchHint(.likely);
        return w.buffer[w.end..];
    }
    try rebase(w, preserve, minimum_len);
    assert(w.buffer.len >= preserve + minimum_len);
    return w.buffer[w.end..];
}

/// Asserts the provided buffer has total capacity enough for `len`.
///
/// Advances the buffer end position by `len`.
///
/// When draining the buffer, ensures that at least `preserve` bytes
/// remain buffered.
///
/// If `preserve` is zero, this is equivalent to `writableSlice`.
pub fn writableSlicePreserve(w: *Writer, preserve: usize, len: usize) Error![]u8 {
    const big_slice = try w.writableSliceGreedyPreserve(preserve, len);
    advance(w, len);
    return big_slice[0..len];
}

pub fn ensureUnusedCapacity(w: *Writer, n: usize) Error!void {
    _ = try writableSliceGreedy(w, n);
}

pub fn undo(w: *Writer, n: usize) void {
    w.end -= n;
}

/// After calling `writableSliceGreedy`, this function tracks how many bytes
/// were written to it.
///
/// This is not needed when using `writableSlice` or `writableArray`.
pub fn advance(w: *Writer, n: usize) void {
    const new_end = w.end + n;
    assert(new_end <= w.buffer.len);
    w.end = new_end;
}

/// The `data` parameter is mutable because this function needs to mutate the
/// fields in order to handle partial writes from `VTable.writeSplat`.
pub fn writeVecAll(w: *Writer, data: [][]const u8) Error!void {
    var index: usize = 0;
    var truncate: usize = 0;
    while (index < data.len) {
        {
            const untruncated = data[index];
            data[index] = untruncated[truncate..];
            defer data[index] = untruncated;
            truncate += try w.writeVec(data[index..]);
        }
        while (index < data.len and truncate >= data[index].len) {
            truncate -= data[index].len;
            index += 1;
        }
    }
}

/// The `data` parameter is mutable because this function needs to mutate the
/// fields in order to handle partial writes from `VTable.writeSplat`.
/// `data` will be restored to its original state before returning.
pub fn writeSplatAll(w: *Writer, data: [][]const u8, splat: usize) Error!void {
    var index: usize = 0;
    var truncate: usize = 0;
    while (index + 1 < data.len) {
        {
            const untruncated = data[index];
            data[index] = untruncated[truncate..];
            defer data[index] = untruncated;
            truncate += try w.writeSplat(data[index..], splat);
        }
        while (truncate >= data[index].len and index + 1 < data.len) {
            truncate -= data[index].len;
            index += 1;
        }
    }

    // Deal with any left over splats
    if (data.len != 0 and truncate < data[index].len * splat) {
        assert(index == data.len - 1);
        var remaining_splat = splat;
        while (true) {
            remaining_splat -= truncate / data[index].len;
            truncate %= data[index].len;
            if (remaining_splat == 0) break;
            truncate += try w.writeSplat(&.{ data[index][truncate..], data[index] }, remaining_splat - 1);
        }
    }
}

test writeSplatAll {
    var aw: Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    var buffers = [_][]const u8{ "ba", "na" };
    try aw.writer.writeSplatAll(&buffers, 2);
    try testing.expectEqualStrings("banana", aw.writer.buffered());
}

test "writeSplatAll works with a single buffer" {
    var aw: Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    var message: [1][]const u8 = .{"hello"};
    try aw.writer.writeSplatAll(&message, 3);
    try testing.expectEqualStrings("hellohellohello", aw.writer.buffered());
}

pub fn write(w: *Writer, bytes: []const u8) Error!usize {
    if (w.end + bytes.len <= w.buffer.len) {
        @branchHint(.likely);
        @memcpy(w.buffer[w.end..][0..bytes.len], bytes);
        w.end += bytes.len;
        return bytes.len;
    }
    return w.vtable.drain(w, &.{bytes}, 1);
}

/// Calls `drain` as many times as necessary such that all of `bytes` are
/// transferred.
pub fn writeAll(w: *Writer, bytes: []const u8) Error!void {
    var index: usize = 0;
    while (index < bytes.len) index += try w.write(bytes[index..]);
}

/// Renders fmt string with args, calling `writer` with slices of bytes.
/// If `writer` returns an error, the error is returned from `format` and
/// `writer` is not called again.
///
/// The format string must be comptime-known and may contain placeholders following
/// this format:
/// `{[argument][specifier]:[fill][alignment][width].[precision]}`
///
/// Above, each word including its surrounding [ and ] is a parameter which you have to replace with something:
///
/// - *argument* is either the numeric index or the field name of the argument that should be inserted
///   - when using a field name, you are required to enclose the field name (an identifier) in square
///     brackets, e.g. {[score]...} as opposed to the numeric index form which can be written e.g. {2...}
/// - *specifier* is a type-dependent formatting option that determines how a type should formatted (see below)
/// - *fill* is a single byte which is used to pad formatted numbers.
/// - *alignment* is one of the three bytes '<', '^', or '>' to make numbers
///   left, center, or right-aligned, respectively.
///   - Not all specifiers support alignment.
///   - Alignment is not Unicode-aware; appropriate only when used with raw bytes or ASCII.
/// - *width* is the total width of the field in bytes. This only applies to number formatting.
/// - *precision* specifies how many decimals a formatted number should have.
///
/// Note that most of the parameters are optional and may be omitted. Also you
/// can leave out separators like `:` and `.` when all parameters after the
/// separator are omitted.
///
/// Only exception is the *fill* parameter. If a non-zero *fill* character is
/// required at the same time as *width* is specified, one has to specify
/// *alignment* as well, as otherwise the digit following `:` is interpreted as
/// *width*, not *fill*.
///
/// The *specifier* has several options for types:
/// - `x` and `X`: output numeric value in hexadecimal notation, or string in hexadecimal bytes
/// - `s`:
///   - for pointer-to-many and C pointers of u8, print as a C-string using zero-termination
///   - for slices of u8, print the entire slice as a string without zero-termination
/// - `t`:
///   - for enums and tagged unions: prints the tag name
///   - for error sets: prints the error name
/// - `b64`: output string as standard base64
/// - `e`: output floating point value in scientific notation
/// - `d`: output numeric value in decimal notation
/// - `b`: output integer value in binary notation
/// - `o`: output integer value in octal notation
/// - `c`: output integer as an ASCII character. Integer type must have 8 bits at max.
/// - `u`: output integer as an UTF-8 sequence. Integer type must have 21 bits at max.
/// - `D`: output nanoseconds as duration
/// - `B`: output bytes in SI units (decimal)
/// - `Bi`: output bytes in IEC units (binary)
/// - `?`: output optional value as either the unwrapped value, or `null`; may be followed by a format specifier for the underlying value.
/// - `!`: output error union value as either the unwrapped value, or the formatted error value; may be followed by a format specifier for the underlying value.
/// - `*`: output the address of the value instead of the value itself.
/// - `any`: output a value of any type using its default format.
/// - `f`: delegates to a method on the type named "format" with the signature `fn (*Writer, args: anytype) Writer.Error!void`.
///
/// A user type may be a `struct`, `vector`, `union` or `enum` type.
///
/// To print literal curly braces, escape them by writing them twice, e.g. `{{` or `}}`.
pub fn print(w: *Writer, comptime fmt: []const u8, args: anytype) Error!void {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);
    if (args_type_info != .@"struct") {
        @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
    }

    const fields_info = args_type_info.@"struct".fields;
    const max_format_args = @typeInfo(std.fmt.ArgSetType).int.bits;
    if (fields_info.len > max_format_args) {
        @compileError("32 arguments max are supported per format call");
    }

    @setEvalBranchQuota(fmt.len * 1000);
    comptime var arg_state: std.fmt.ArgState = .{ .args_len = fields_info.len };
    comptime var i = 0;
    comptime var literal: []const u8 = "";
    inline while (true) {
        const start_index = i;

        inline while (i < fmt.len) : (i += 1) {
            switch (fmt[i]) {
                '{', '}' => break,
                else => {},
            }
        }

        comptime var end_index = i;
        comptime var unescape_brace = false;

        // Handle {{ and }}, those are un-escaped as single braces
        if (i + 1 < fmt.len and fmt[i + 1] == fmt[i]) {
            unescape_brace = true;
            // Make the first brace part of the literal...
            end_index += 1;
            // ...and skip both
            i += 2;
        }

        literal = literal ++ fmt[start_index..end_index];

        // We've already skipped the other brace, restart the loop
        if (unescape_brace) continue;

        // Write out the literal
        if (literal.len != 0) {
            try w.writeAll(literal);
            literal = "";
        }

        if (i >= fmt.len) break;

        if (fmt[i] == '}') {
            @compileError("missing opening {");
        }

        // Get past the {
        comptime assert(fmt[i] == '{');
        i += 1;

        const fmt_begin = i;
        // Find the closing brace
        inline while (i < fmt.len and fmt[i] != '}') : (i += 1) {}
        const fmt_end = i;

        if (i >= fmt.len) {
            @compileError("missing closing }");
        }

        // Get past the }
        comptime assert(fmt[i] == '}');
        i += 1;

        const placeholder_array = fmt[fmt_begin..fmt_end].*;
        const placeholder = comptime std.fmt.Placeholder.parse(&placeholder_array);
        const arg_pos = comptime switch (placeholder.arg) {
            .none => null,
            .number => |pos| pos,
            .named => |arg_name| std.meta.fieldIndex(ArgsType, arg_name) orelse
                @compileError("no argument with name '" ++ arg_name ++ "'"),
        };

        const width = switch (placeholder.width) {
            .none => null,
            .number => |v| v,
            .named => |arg_name| blk: {
                const arg_i = comptime std.meta.fieldIndex(ArgsType, arg_name) orelse
                    @compileError("no argument with name '" ++ arg_name ++ "'");
                _ = comptime arg_state.nextArg(arg_i) orelse @compileError("too few arguments");
                break :blk @field(args, arg_name);
            },
        };

        const precision = switch (placeholder.precision) {
            .none => null,
            .number => |v| v,
            .named => |arg_name| blk: {
                const arg_i = comptime std.meta.fieldIndex(ArgsType, arg_name) orelse
                    @compileError("no argument with name '" ++ arg_name ++ "'");
                _ = comptime arg_state.nextArg(arg_i) orelse @compileError("too few arguments");
                break :blk @field(args, arg_name);
            },
        };

        const arg_to_print = comptime arg_state.nextArg(arg_pos) orelse
            @compileError("too few arguments");

        try w.printValue(
            placeholder.specifier_arg,
            .{
                .fill = placeholder.fill,
                .alignment = placeholder.alignment,
                .width = width,
                .precision = precision,
            },
            @field(args, fields_info[arg_to_print].name),
            std.options.fmt_max_depth,
        );
    }

    if (comptime arg_state.hasUnusedArgs()) {
        const missing_count = arg_state.args_len - @popCount(arg_state.used_args);
        switch (missing_count) {
            0 => unreachable,
            1 => @compileError("unused argument in '" ++ fmt ++ "'"),
            else => @compileError(std.fmt.comptimePrint("{d}", .{missing_count}) ++ " unused arguments in '" ++ fmt ++ "'"),
        }
    }
}

/// Calls `drain` as many times as necessary such that `byte` is transferred.
pub fn writeByte(w: *Writer, byte: u8) Error!void {
    while (w.buffer.len - w.end == 0) {
        const n = try w.vtable.drain(w, &.{&.{byte}}, 1);
        if (n > 0) return;
    } else {
        @branchHint(.likely);
        w.buffer[w.end] = byte;
        w.end += 1;
    }
}

/// When draining the buffer, ensures that at least `preserve` bytes
/// remain buffered.
pub fn writeBytePreserve(w: *Writer, preserve: usize, byte: u8) Error!void {
    if (w.buffer.len - w.end != 0) {
        @branchHint(.likely);
        w.buffer[w.end] = byte;
        w.end += 1;
        return;
    }
    try w.vtable.rebase(w, preserve, 1);
    w.buffer[w.end] = byte;
    w.end += 1;
}

/// Writes the same byte many times, performing the underlying write call as
/// many times as necessary.
pub fn splatByteAll(w: *Writer, byte: u8, n: usize) Error!void {
    var remaining: usize = n;
    while (remaining > 0) remaining -= try w.splatByte(byte, remaining);
}

test splatByteAll {
    var aw: Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    try aw.writer.splatByteAll('7', 45);
    try testing.expectEqualStrings("7" ** 45, aw.writer.buffered());
}

pub fn splatBytePreserve(w: *Writer, preserve: usize, byte: u8, n: usize) Error!void {
    const new_end = w.end + n;
    if (new_end <= w.buffer.len) {
        @memset(w.buffer[w.end..][0..n], byte);
        w.end = new_end;
        return;
    }
    // If `n` is large, we can ignore `preserve` up to a point.
    var remaining = n;
    while (remaining > preserve) {
        assert(remaining != 0);
        remaining -= try splatByte(w, byte, remaining - preserve);
        if (w.end + remaining <= w.buffer.len) {
            @memset(w.buffer[w.end..][0..remaining], byte);
            w.end += remaining;
            return;
        }
    }
    // All the next bytes received must be preserved.
    if (preserve < w.end) {
        @memmove(w.buffer[0..preserve], w.buffer[w.end - preserve ..][0..preserve]);
        w.end = preserve;
    }
    while (remaining > 0) remaining -= try w.splatByte(byte, remaining);
}

/// Writes the same byte many times, allowing short writes.
///
/// Does maximum of one underlying `VTable.drain`.
pub fn splatByte(w: *Writer, byte: u8, n: usize) Error!usize {
    if (w.end + n <= w.buffer.len) {
        @branchHint(.likely);
        @memset(w.buffer[w.end..][0..n], byte);
        w.end += n;
        return n;
    }
    return writeSplat(w, &.{&.{byte}}, n);
}

/// Writes the same slice many times, performing the underlying write call as
/// many times as necessary.
pub fn splatBytesAll(w: *Writer, bytes: []const u8, splat: usize) Error!void {
    var remaining_bytes: usize = bytes.len * splat;
    remaining_bytes -= try w.splatBytes(bytes, splat);
    while (remaining_bytes > 0) {
        const leftover_splat = remaining_bytes / bytes.len;
        const leftover_bytes = remaining_bytes % bytes.len;
        const buffers: [2][]const u8 = .{ bytes[bytes.len - leftover_bytes ..], bytes };
        remaining_bytes -= try w.writeSplat(&buffers, leftover_splat);
    }
}

test splatBytesAll {
    var aw: Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    try aw.writer.splatBytesAll("hello", 3);
    try testing.expectEqualStrings("hellohellohello", aw.writer.buffered());
}

/// Writes the same slice many times, allowing short writes.
///
/// Does maximum of one underlying `VTable.drain`.
pub fn splatBytes(w: *Writer, bytes: []const u8, n: usize) Error!usize {
    return writeSplat(w, &.{bytes}, n);
}

/// Asserts the `buffer` was initialized with a capacity of at least `@sizeOf(T)` bytes.
pub inline fn writeInt(w: *Writer, comptime T: type, value: T, endian: std.builtin.Endian) Error!void {
    var bytes: [@divExact(@typeInfo(T).int.bits, 8)]u8 = undefined;
    std.mem.writeInt(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value, endian);
    return w.writeAll(&bytes);
}

/// The function is inline to avoid the dead code in case `endian` is
/// comptime-known and matches host endianness.
pub inline fn writeStruct(w: *Writer, value: anytype, endian: std.builtin.Endian) Error!void {
    switch (@typeInfo(@TypeOf(value))) {
        .@"struct" => |info| switch (info.layout) {
            .auto => @compileError("ill-defined memory layout"),
            .@"extern" => {
                if (native_endian == endian) {
                    return w.writeAll(@ptrCast((&value)[0..1]));
                } else {
                    var copy = value;
                    std.mem.byteSwapAllFields(@TypeOf(value), &copy);
                    return w.writeAll(@ptrCast((&copy)[0..1]));
                }
            },
            .@"packed" => {
                return writeInt(w, info.backing_integer.?, @bitCast(value), endian);
            },
        },
        else => @compileError("not a struct"),
    }
}

pub inline fn writeSliceEndian(
    w: *Writer,
    Elem: type,
    slice: []const Elem,
    endian: std.builtin.Endian,
) Error!void {
    switch (@typeInfo(Elem)) {
        .@"struct" => |info| comptime assert(info.layout != .auto),
        .int, .@"enum" => {},
        else => @compileError("ill-defined memory layout"),
    }
    if (native_endian == endian) {
        return writeAll(w, @ptrCast(slice));
    } else {
        return writeSliceSwap(w, Elem, slice);
    }
}

pub fn writeSliceSwap(w: *Writer, Elem: type, slice: []const Elem) Error!void {
    for (slice) |elem| {
        var tmp = elem;
        std.mem.byteSwapAllFields(Elem, &tmp);
        try w.writeAll(@ptrCast(&tmp));
    }
}

/// Unlike `writeSplat` and `writeVec`, this function will call into `VTable`
/// even if there is enough buffer capacity for the file contents.
///
/// The caller is responsible for flushing. Although the buffer may be bypassed
/// as an optimization, this is not a guarantee.
///
/// Although it would be possible to eliminate `error.Unimplemented` from the
/// error set by reading directly into the buffer in such case, this is not
/// done because it is more efficient to do it higher up the call stack so that
/// the error does not occur with each write.
///
/// See `sendFileReading` for an alternative that does not have
/// `error.Unimplemented` in the error set.
pub fn sendFile(w: *Writer, file_reader: *File.Reader, limit: Limit) FileError!usize {
    return w.vtable.sendFile(w, file_reader, limit);
}

/// Returns how many bytes from `header` and `file_reader` were consumed.
///
/// `limit` only applies to `file_reader`.
pub fn sendFileHeader(
    w: *Writer,
    header: []const u8,
    file_reader: *File.Reader,
    limit: Limit,
) FileError!usize {
    const new_end = w.end + header.len;
    if (new_end <= w.buffer.len) {
        @memcpy(w.buffer[w.end..][0..header.len], header);
        w.end = new_end;
        return header.len + try w.vtable.sendFile(w, file_reader, limit);
    }
    const buffered_contents = limit.slice(file_reader.interface.buffered());
    const n = try w.vtable.drain(w, &.{ header, buffered_contents }, 1);
    file_reader.interface.toss(n -| header.len);
    return n;
}

/// Asserts nonzero buffer capacity.
pub fn sendFileReading(w: *Writer, file_reader: *File.Reader, limit: Limit) FileReadingError!usize {
    const dest = limit.slice(try w.writableSliceGreedy(1));
    const n = try file_reader.read(dest);
    w.advance(n);
    return n;
}

/// Number of bytes logically written is returned. This excludes bytes from
/// `buffer` because they have already been logically written.
///
/// The caller is responsible for flushing. Although the buffer may be bypassed
/// as an optimization, this is not a guarantee.
///
/// Asserts nonzero buffer capacity.
pub fn sendFileAll(w: *Writer, file_reader: *File.Reader, limit: Limit) FileAllError!usize {
    // The fallback sendFileReadingAll() path asserts non-zero buffer capacity.
    // Explicitly assert it here as well to ensure the assert is hit even if
    // the fallback path is not taken.
    assert(w.buffer.len > 0);
    var remaining = @intFromEnum(limit);
    while (remaining > 0) {
        const n = sendFile(w, file_reader, .limited(remaining)) catch |err| switch (err) {
            error.EndOfStream => break,
            error.Unimplemented => {
                file_reader.mode = file_reader.mode.toReading();
                remaining -= try w.sendFileReadingAll(file_reader, .limited(remaining));
                break;
            },
            else => |e| return e,
        };
        remaining -= n;
    }
    return @intFromEnum(limit) - remaining;
}

/// Equivalent to `sendFileAll` but uses direct `pread` and `read` calls on
/// `file` rather than `sendFile`. This is generally used as a fallback when
/// the underlying implementation returns `error.Unimplemented`, which is why
/// that error code does not appear in this function's error set.
///
/// Asserts nonzero buffer capacity.
pub fn sendFileReadingAll(w: *Writer, file_reader: *File.Reader, limit: Limit) FileAllError!usize {
    var remaining = @intFromEnum(limit);
    while (remaining > 0) {
        remaining -= sendFileReading(w, file_reader, .limited(remaining)) catch |err| switch (err) {
            error.EndOfStream => break,
            else => |e| return e,
        };
    }
    return @intFromEnum(limit) - remaining;
}

pub fn alignBuffer(
    w: *Writer,
    buffer: []const u8,
    width: usize,
    alignment: std.fmt.Alignment,
    fill: u8,
) Error!void {
    const padding = if (buffer.len < width) width - buffer.len else 0;
    if (padding == 0) {
        @branchHint(.likely);
        return w.writeAll(buffer);
    }
    switch (alignment) {
        .left => {
            try w.writeAll(buffer);
            try w.splatByteAll(fill, padding);
        },
        .center => {
            const left_padding = padding / 2;
            const right_padding = (padding + 1) / 2;
            try w.splatByteAll(fill, left_padding);
            try w.writeAll(buffer);
            try w.splatByteAll(fill, right_padding);
        },
        .right => {
            try w.splatByteAll(fill, padding);
            try w.writeAll(buffer);
        },
    }
}

pub fn alignBufferOptions(w: *Writer, buffer: []const u8, options: std.fmt.Options) Error!void {
    return w.alignBuffer(buffer, options.width orelse buffer.len, options.alignment, options.fill);
}

pub fn printAddress(w: *Writer, value: anytype) Error!void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .pointer => |info| {
            try w.writeAll(@typeName(info.child) ++ "@");
            const int = if (info.size == .slice) @intFromPtr(value.ptr) else @intFromPtr(value);
            return w.printInt(int, 16, .lower, .{});
        },
        .optional => |info| {
            if (@typeInfo(info.child) == .pointer) {
                try w.writeAll(@typeName(info.child) ++ "@");
                try w.printInt(@intFromPtr(value), 16, .lower, .{});
                return;
            }
        },
        else => {},
    }

    @compileError("cannot format non-pointer type " ++ @typeName(T) ++ " with * specifier");
}

/// Asserts `buffer` capacity of at least 2 if `value` is a union.
pub fn printValue(
    w: *Writer,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    value: anytype,
    max_depth: usize,
) Error!void {
    const T = @TypeOf(value);

    switch (fmt.len) {
        1 => switch (fmt[0]) {
            '*' => return w.printAddress(value),
            'f' => return value.format(w),
            'd' => switch (@typeInfo(T)) {
                .float, .comptime_float => return printFloat(w, value, options.toNumber(.decimal, .lower)),
                .int, .comptime_int => return printInt(w, value, 10, .lower, options),
                .@"struct" => return value.formatNumber(w, options.toNumber(.decimal, .lower)),
                .@"enum" => return printInt(w, @intFromEnum(value), 10, .lower, options),
                .vector => return printVector(w, fmt, options, value, max_depth),
                else => invalidFmtError(fmt, value),
            },
            'c' => return w.printAsciiChar(value, options),
            'u' => return w.printUnicodeCodepoint(value),
            'b' => switch (@typeInfo(T)) {
                .int, .comptime_int => return printInt(w, value, 2, .lower, options),
                .@"enum" => return printInt(w, @intFromEnum(value), 2, .lower, options),
                .@"struct" => return value.formatNumber(w, options.toNumber(.binary, .lower)),
                .vector => return printVector(w, fmt, options, value, max_depth),
                else => invalidFmtError(fmt, value),
            },
            'o' => switch (@typeInfo(T)) {
                .int, .comptime_int => return printInt(w, value, 8, .lower, options),
                .@"enum" => return printInt(w, @intFromEnum(value), 8, .lower, options),
                .@"struct" => return value.formatNumber(w, options.toNumber(.octal, .lower)),
                .vector => return printVector(w, fmt, options, value, max_depth),
                else => invalidFmtError(fmt, value),
            },
            'x' => switch (@typeInfo(T)) {
                .float, .comptime_float => return printFloatHexOptions(w, value, options.toNumber(.hex, .lower)),
                .int, .comptime_int => return printInt(w, value, 16, .lower, options),
                .@"enum" => return printInt(w, @intFromEnum(value), 16, .lower, options),
                .@"struct" => return value.formatNumber(w, options.toNumber(.hex, .lower)),
                .pointer => |info| switch (info.size) {
                    .one, .slice => {
                        const slice: []const u8 = value;
                        optionsForbidden(options);
                        return printHex(w, slice, .lower);
                    },
                    .many, .c => {
                        const slice: [:0]const u8 = std.mem.span(value);
                        optionsForbidden(options);
                        return printHex(w, slice, .lower);
                    },
                },
                .array => {
                    const slice: []const u8 = &value;
                    optionsForbidden(options);
                    return printHex(w, slice, .lower);
                },
                .vector => return printVector(w, fmt, options, value, max_depth),
                else => invalidFmtError(fmt, value),
            },
            'X' => switch (@typeInfo(T)) {
                .float, .comptime_float => return printFloatHexOptions(w, value, options.toNumber(.hex, .upper)),
                .int, .comptime_int => return printInt(w, value, 16, .upper, options),
                .@"enum" => return printInt(w, @intFromEnum(value), 16, .upper, options),
                .@"struct" => return value.formatNumber(w, options.toNumber(.hex, .upper)),
                .pointer => |info| switch (info.size) {
                    .one, .slice => {
                        const slice: []const u8 = value;
                        optionsForbidden(options);
                        return printHex(w, slice, .upper);
                    },
                    .many, .c => {
                        const slice: [:0]const u8 = std.mem.span(value);
                        optionsForbidden(options);
                        return printHex(w, slice, .upper);
                    },
                },
                .array => {
                    const slice: []const u8 = &value;
                    optionsForbidden(options);
                    return printHex(w, slice, .upper);
                },
                .vector => return printVector(w, fmt, options, value, max_depth),
                else => invalidFmtError(fmt, value),
            },
            's' => switch (@typeInfo(T)) {
                .pointer => |info| switch (info.size) {
                    .one, .slice => {
                        const slice: []const u8 = value;
                        return w.alignBufferOptions(slice, options);
                    },
                    .many, .c => {
                        const slice: [:0]const u8 = std.mem.span(value);
                        return w.alignBufferOptions(slice, options);
                    },
                },
                .array => {
                    const slice: []const u8 = &value;
                    return w.alignBufferOptions(slice, options);
                },
                else => invalidFmtError(fmt, value),
            },
            'B' => switch (@typeInfo(T)) {
                .int, .comptime_int => return w.printByteSize(value, .decimal, options),
                .@"struct" => return value.formatByteSize(w, .decimal),
                else => invalidFmtError(fmt, value),
            },
            'D' => switch (@typeInfo(T)) {
                .int, .comptime_int => return w.printDuration(value, options),
                .@"struct" => return value.formatDuration(w),
                else => invalidFmtError(fmt, value),
            },
            'e' => switch (@typeInfo(T)) {
                .float, .comptime_float => return printFloat(w, value, options.toNumber(.scientific, .lower)),
                .@"struct" => return value.formatNumber(w, options.toNumber(.scientific, .lower)),
                else => invalidFmtError(fmt, value),
            },
            'E' => switch (@typeInfo(T)) {
                .float, .comptime_float => return printFloat(w, value, options.toNumber(.scientific, .upper)),
                .@"struct" => return value.formatNumber(w, options.toNumber(.scientific, .upper)),
                else => invalidFmtError(fmt, value),
            },
            't' => switch (@typeInfo(T)) {
                .error_set => return w.alignBufferOptions(@errorName(value), options),
                .@"enum", .@"union" => return w.alignBufferOptions(@tagName(value), options),
                else => invalidFmtError(fmt, value),
            },
            else => {},
        },
        2 => switch (fmt[0]) {
            'B' => switch (fmt[1]) {
                'i' => switch (@typeInfo(T)) {
                    .int, .comptime_int => return w.printByteSize(value, .binary, options),
                    .@"struct" => return value.formatByteSize(w, .binary),
                    else => invalidFmtError(fmt, value),
                },
                else => {},
            },
            else => {},
        },
        3 => if (fmt[0] == 'b' and fmt[1] == '6' and fmt[2] == '4') switch (@typeInfo(T)) {
            .pointer => |info| switch (info.size) {
                .one, .slice => {
                    const slice: []const u8 = value;
                    optionsForbidden(options);
                    return w.printBase64(slice);
                },
                .many, .c => {
                    const slice: [:0]const u8 = std.mem.span(value);
                    optionsForbidden(options);
                    return w.printBase64(slice);
                },
            },
            .array => {
                const slice: []const u8 = &value;
                optionsForbidden(options);
                return w.printBase64(slice);
            },
            else => invalidFmtError(fmt, value),
        },
        else => {},
    }

    const is_any = comptime std.mem.eql(u8, fmt, ANY);
    if (!is_any and std.meta.hasMethod(T, "format") and fmt.len == 0) {
        // after 0.15.0 is tagged, delete this compile error and its condition
        @compileError("ambiguous format string; specify {f} to call format method, or {any} to skip it");
    }

    switch (@typeInfo(T)) {
        .float, .comptime_float => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            return printFloat(w, value, options.toNumber(.decimal, .lower));
        },
        .int, .comptime_int => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            return printInt(w, value, 10, .lower, options);
        },
        .bool => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            const string: []const u8 = if (value) "true" else "false";
            return w.alignBufferOptions(string, options);
        },
        .void => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            return w.alignBufferOptions("void", options);
        },
        .optional => {
            const remaining_fmt = comptime if (fmt.len > 0 and fmt[0] == '?')
                stripOptionalOrErrorUnionSpec(fmt)
            else if (is_any)
                ANY
            else
                @compileError("cannot print optional without a specifier (i.e. {?} or {any})");
            if (value) |payload| {
                return w.printValue(remaining_fmt, options, payload, max_depth);
            } else {
                return w.alignBufferOptions("null", options);
            }
        },
        .error_union => {
            const remaining_fmt = comptime if (fmt.len > 0 and fmt[0] == '!')
                stripOptionalOrErrorUnionSpec(fmt)
            else if (is_any)
                ANY
            else
                @compileError("cannot print error union without a specifier (i.e. {!} or {any})");
            if (value) |payload| {
                return w.printValue(remaining_fmt, options, payload, max_depth);
            } else |err| {
                return w.printValue("", options, err, max_depth);
            }
        },
        .error_set => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            optionsForbidden(options);
            return printErrorSet(w, value);
        },
        .@"enum" => |info| {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            optionsForbidden(options);
            if (info.is_exhaustive) {
                return printEnumExhaustive(w, value);
            } else {
                return printEnumNonexhaustive(w, value);
            }
        },
        .@"union" => |info| {
            if (!is_any) {
                if (fmt.len != 0) invalidFmtError(fmt, value);
                return printValue(w, ANY, options, value, max_depth);
            }
            if (max_depth == 0) {
                try w.writeAll(".{ ... }");
                return;
            }
            if (info.tag_type) |UnionTagType| {
                try w.writeAll(".{ .");
                try w.writeAll(@tagName(@as(UnionTagType, value)));
                try w.writeAll(" = ");
                inline for (info.fields) |u_field| {
                    if (value == @field(UnionTagType, u_field.name)) {
                        try w.printValue(ANY, options, @field(value, u_field.name), max_depth - 1);
                    }
                }
                try w.writeAll(" }");
            } else switch (info.layout) {
                .auto => {
                    return w.writeAll(".{ ... }");
                },
                .@"extern", .@"packed" => {
                    if (info.fields.len == 0) return w.writeAll(".{}");
                    try w.writeAll(".{ ");
                    inline for (info.fields, 1..) |field, i| {
                        try w.writeByte('.');
                        try w.writeAll(field.name);
                        try w.writeAll(" = ");
                        try w.printValue(ANY, options, @field(value, field.name), max_depth - 1);
                        try w.writeAll(if (i < info.fields.len) ", " else " }");
                    }
                },
            }
        },
        .@"struct" => |info| {
            if (!is_any) {
                if (fmt.len != 0) invalidFmtError(fmt, value);
                return printValue(w, ANY, options, value, max_depth);
            }
            if (info.is_tuple) {
                // Skip the type and field names when formatting tuples.
                if (max_depth == 0) {
                    try w.writeAll(".{ ... }");
                    return;
                }
                try w.writeAll(".{");
                inline for (info.fields, 0..) |f, i| {
                    if (i == 0) {
                        try w.writeAll(" ");
                    } else {
                        try w.writeAll(", ");
                    }
                    try w.printValue(ANY, options, @field(value, f.name), max_depth - 1);
                }
                try w.writeAll(" }");
                return;
            }
            if (max_depth == 0) {
                try w.writeAll(".{ ... }");
                return;
            }
            try w.writeAll(".{");
            inline for (info.fields, 0..) |f, i| {
                if (i == 0) {
                    try w.writeAll(" .");
                } else {
                    try w.writeAll(", .");
                }
                try w.writeAll(f.name);
                try w.writeAll(" = ");
                try w.printValue(ANY, options, @field(value, f.name), max_depth - 1);
            }
            try w.writeAll(" }");
        },
        .pointer => |ptr_info| switch (ptr_info.size) {
            .one => switch (@typeInfo(ptr_info.child)) {
                .array => |array_info| return w.printValue(fmt, options, @as([]const array_info.child, value), max_depth),
                .@"enum", .@"union", .@"struct" => return w.printValue(fmt, options, value.*, max_depth),
                else => {
                    var buffers: [2][]const u8 = .{ @typeName(ptr_info.child), "@" };
                    try w.writeVecAll(&buffers);
                    try w.printInt(@intFromPtr(value), 16, .lower, options);
                    return;
                },
            },
            .many, .c => {
                if (!is_any) @compileError("cannot format pointer without a specifier (i.e. {s} or {*})");
                optionsForbidden(options);
                try w.printAddress(value);
            },
            .slice => {
                if (!is_any)
                    @compileError("cannot format slice without a specifier (i.e. {s}, {x}, {b64}, or {any})");
                if (max_depth == 0) return w.writeAll("{ ... }");
                try w.writeAll("{ ");
                for (value, 0..) |elem, i| {
                    try w.printValue(fmt, options, elem, max_depth - 1);
                    if (i != value.len - 1) {
                        try w.writeAll(", ");
                    }
                }
                try w.writeAll(" }");
            },
        },
        .array => {
            if (!is_any) @compileError("cannot format array without a specifier (i.e. {s} or {any})");
            return printArray(w, fmt, options, &value, max_depth);
        },
        .vector => |vector| {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            const array: [vector.len]vector.child = value;
            return printArray(w, fmt, options, &array, max_depth);
        },
        .@"fn" => @compileError("unable to format function body type, use '*const " ++ @typeName(T) ++ "' for a function pointer type"),
        .type => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            return w.alignBufferOptions(@typeName(value), options);
        },
        .enum_literal => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            optionsForbidden(options);
            var vecs: [2][]const u8 = .{ ".", @tagName(value) };
            return w.writeVecAll(&vecs);
        },
        .null => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            return w.alignBufferOptions("null", options);
        },
        else => @compileError("unable to format type '" ++ @typeName(T) ++ "'"),
    }
}

fn optionsForbidden(options: std.fmt.Options) void {
    assert(options.precision == null);
    assert(options.width == null);
}

fn printErrorSet(w: *Writer, error_set: anyerror) Error!void {
    var vecs: [2][]const u8 = .{ "error.", @errorName(error_set) };
    try w.writeVecAll(&vecs);
}

fn printEnumExhaustive(w: *Writer, value: anytype) Error!void {
    var vecs: [2][]const u8 = .{ ".", @tagName(value) };
    try w.writeVecAll(&vecs);
}

fn printEnumNonexhaustive(w: *Writer, value: anytype) Error!void {
    if (std.enums.tagName(@TypeOf(value), value)) |tag_name| {
        var vecs: [2][]const u8 = .{ ".", tag_name };
        try w.writeVecAll(&vecs);
        return;
    }
    try w.writeAll("@enumFromInt(");
    try w.printInt(@intFromEnum(value), 10, .lower, .{});
    try w.writeByte(')');
}

pub fn printVector(
    w: *Writer,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    value: anytype,
    max_depth: usize,
) Error!void {
    const vector = @typeInfo(@TypeOf(value)).vector;
    const array: [vector.len]vector.child = value;
    return printArray(w, fmt, options, &array, max_depth);
}

pub fn printArray(
    w: *Writer,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    ptr_to_array: anytype,
    max_depth: usize,
) Error!void {
    if (max_depth == 0) return w.writeAll("{ ... }");
    try w.writeAll("{ ");
    for (ptr_to_array, 0..) |elem, i| {
        try w.printValue(fmt, options, elem, max_depth - 1);
        if (i < ptr_to_array.len - 1) {
            try w.writeAll(", ");
        }
    }
    try w.writeAll(" }");
}

// A wrapper around `printIntAny` to avoid the generic explosion of this
// function by funneling smaller integer types through `isize` and `usize`.
pub inline fn printInt(
    w: *Writer,
    value: anytype,
    base: u8,
    case: std.fmt.Case,
    options: std.fmt.Options,
) Error!void {
    switch (@TypeOf(value)) {
        isize, usize => {},
        comptime_int => {
            if (comptime std.math.cast(usize, value)) |x| return printIntAny(w, x, base, case, options);
            if (comptime std.math.cast(isize, value)) |x| return printIntAny(w, x, base, case, options);
            const Int = std.math.IntFittingRange(value, value);
            return printIntAny(w, @as(Int, value), base, case, options);
        },
        else => switch (@typeInfo(@TypeOf(value)).int.signedness) {
            .signed => if (std.math.cast(isize, value)) |x| return printIntAny(w, x, base, case, options),
            .unsigned => if (std.math.cast(usize, value)) |x| return printIntAny(w, x, base, case, options),
        },
    }
    return printIntAny(w, value, base, case, options);
}

/// In general, prefer `printInt` to avoid generic explosion. However this
/// function may be used when optimal codegen for a particular integer type is
/// desired.
pub fn printIntAny(
    w: *Writer,
    value: anytype,
    base: u8,
    case: std.fmt.Case,
    options: std.fmt.Options,
) Error!void {
    assert(base >= 2);
    const value_info = @typeInfo(@TypeOf(value)).int;

    // The type must have the same size as `base` or be wider in order for the
    // division to work
    const min_int_bits = comptime @max(value_info.bits, 8);
    const MinInt = std.meta.Int(.unsigned, min_int_bits);

    const abs_value = @abs(value);
    // The worst case in terms of space needed is base 2, plus 1 for the sign
    var buf: [1 + @max(@as(comptime_int, value_info.bits), 1)]u8 = undefined;

    var a: MinInt = abs_value;
    var index: usize = buf.len;

    if (base == 10) {
        while (a >= 100) : (a = @divTrunc(a, 100)) {
            index -= 2;
            buf[index..][0..2].* = std.fmt.digits2(@intCast(a % 100));
        }

        if (a < 10) {
            index -= 1;
            buf[index] = '0' + @as(u8, @intCast(a));
        } else {
            index -= 2;
            buf[index..][0..2].* = std.fmt.digits2(@intCast(a));
        }
    } else {
        while (true) {
            const digit = a % base;
            index -= 1;
            buf[index] = std.fmt.digitToChar(@intCast(digit), case);
            a /= base;
            if (a == 0) break;
        }
    }

    if (value_info.signedness == .signed) {
        if (value < 0) {
            // Negative integer
            index -= 1;
            buf[index] = '-';
        } else if (options.width == null or options.width.? == 0) {
            // Positive integer, omit the plus sign
        } else {
            // Positive integer
            index -= 1;
            buf[index] = '+';
        }
    }

    return w.alignBufferOptions(buf[index..], options);
}

pub fn printAsciiChar(w: *Writer, c: u8, options: std.fmt.Options) Error!void {
    return w.alignBufferOptions(@as(*const [1]u8, &c), options);
}

pub fn printAscii(w: *Writer, bytes: []const u8, options: std.fmt.Options) Error!void {
    return w.alignBufferOptions(bytes, options);
}

pub fn printUnicodeCodepoint(w: *Writer, c: u21) Error!void {
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(c, &buf) catch |err| switch (err) {
        error.Utf8CannotEncodeSurrogateHalf, error.CodepointTooLarge => l: {
            buf[0..3].* = std.unicode.replacement_character_utf8;
            break :l 3;
        },
    };
    return w.writeAll(buf[0..len]);
}

/// Uses a larger stack buffer; asserts mode is decimal or scientific.
pub fn printFloat(w: *Writer, value: anytype, options: std.fmt.Number) Error!void {
    const mode: std.fmt.float.Mode = switch (options.mode) {
        .decimal => .decimal,
        .scientific => .scientific,
        .binary, .octal, .hex => unreachable,
    };
    var buf: [std.fmt.float.bufferSize(.decimal, f64)]u8 = undefined;
    const s = std.fmt.float.render(&buf, value, .{
        .mode = mode,
        .precision = options.precision,
    }) catch |err| switch (err) {
        error.BufferTooSmall => "(float)",
    };
    return w.alignBuffer(s, options.width orelse s.len, options.alignment, options.fill);
}

/// Uses a smaller stack buffer; asserts mode is not decimal or scientific.
pub fn printFloatHexOptions(w: *Writer, value: anytype, options: std.fmt.Number) Error!void {
    var buf: [50]u8 = undefined; // for aligning
    var sub_writer: Writer = .fixed(&buf);
    switch (options.mode) {
        .decimal => unreachable,
        .scientific => unreachable,
        .binary => @panic("TODO"),
        .octal => @panic("TODO"),
        .hex => {},
    }
    printFloatHex(&sub_writer, value, options.case, options.precision) catch unreachable; // buf is large enough

    const printed = sub_writer.buffered();
    return w.alignBuffer(printed, options.width orelse printed.len, options.alignment, options.fill);
}

pub fn printFloatHex(w: *Writer, value: anytype, case: std.fmt.Case, opt_precision: ?usize) Error!void {
    const v = switch (@TypeOf(value)) {
        // comptime_float internally is a f128; this preserves precision.
        comptime_float => @as(f128, value),
        else => value,
    };

    if (std.math.signbit(v)) try w.writeByte('-');
    if (std.math.isNan(v)) return w.writeAll(switch (case) {
        .lower => "nan",
        .upper => "NAN",
    });
    if (std.math.isInf(v)) return w.writeAll(switch (case) {
        .lower => "inf",
        .upper => "INF",
    });

    const T = @TypeOf(v);
    const TU = std.meta.Int(.unsigned, @bitSizeOf(T));

    const mantissa_bits = std.math.floatMantissaBits(T);
    const fractional_bits = std.math.floatFractionalBits(T);
    const exponent_bits = std.math.floatExponentBits(T);
    const mantissa_mask = (1 << mantissa_bits) - 1;
    const exponent_mask = (1 << exponent_bits) - 1;
    const exponent_bias = (1 << (exponent_bits - 1)) - 1;

    const as_bits: TU = @bitCast(v);
    var mantissa = as_bits & mantissa_mask;
    var exponent: i32 = @as(u16, @truncate((as_bits >> mantissa_bits) & exponent_mask));

    const is_denormal = exponent == 0 and mantissa != 0;
    const is_zero = exponent == 0 and mantissa == 0;

    if (is_zero) {
        // Handle this case here to simplify the logic below.
        try w.writeAll("0x0");
        if (opt_precision) |precision| {
            if (precision > 0) {
                try w.writeAll(".");
                try w.splatByteAll('0', precision);
            }
        } else {
            try w.writeAll(".0");
        }
        try w.writeAll("p0");
        return;
    }

    if (is_denormal) {
        // Adjust the exponent for printing.
        exponent += 1;
    } else {
        if (fractional_bits == mantissa_bits)
            mantissa |= 1 << fractional_bits; // Add the implicit integer bit.
    }

    const mantissa_digits = (fractional_bits + 3) / 4;
    // Fill in zeroes to round the fraction width to a multiple of 4.
    mantissa <<= mantissa_digits * 4 - fractional_bits;

    if (opt_precision) |precision| {
        // Round if needed.
        if (precision < mantissa_digits) {
            // We always have at least 4 extra bits.
            var extra_bits = (mantissa_digits - precision) * 4;
            // The result LSB is the Guard bit, we need two more (Round and
            // Sticky) to round the value.
            while (extra_bits > 2) {
                mantissa = (mantissa >> 1) | (mantissa & 1);
                extra_bits -= 1;
            }
            // Round to nearest, tie to even.
            mantissa |= @intFromBool(mantissa & 0b100 != 0);
            mantissa += 1;
            // Drop the excess bits.
            mantissa >>= 2;
            // Restore the alignment.
            mantissa <<= @as(std.math.Log2Int(TU), @intCast((mantissa_digits - precision) * 4));

            const overflow = mantissa & (1 << 1 + mantissa_digits * 4) != 0;
            // Prefer a normalized result in case of overflow.
            if (overflow) {
                mantissa >>= 1;
                exponent += 1;
            }
        }
    }

    // +1 for the decimal part.
    var buf: [1 + mantissa_digits]u8 = undefined;
    assert(std.fmt.printInt(&buf, mantissa, 16, case, .{ .fill = '0', .width = 1 + mantissa_digits }) == buf.len);

    try w.writeAll("0x");
    try w.writeByte(buf[0]);
    const trimmed = std.mem.trimRight(u8, buf[1..], "0");
    if (opt_precision) |precision| {
        if (precision > 0) try w.writeAll(".");
    } else if (trimmed.len > 0) {
        try w.writeAll(".");
    }
    try w.writeAll(trimmed);
    // Add trailing zeros if explicitly requested.
    if (opt_precision) |precision| if (precision > 0) {
        if (precision > trimmed.len)
            try w.splatByteAll('0', precision - trimmed.len);
    };
    try w.writeAll("p");
    try w.printInt(exponent - exponent_bias, 10, case, .{});
}

pub const ByteSizeUnits = enum {
    /// This formatter represents the number as multiple of 1000 and uses the SI
    /// measurement units (kB, MB, GB, ...).
    decimal,
    /// This formatter represents the number as multiple of 1024 and uses the IEC
    /// measurement units (KiB, MiB, GiB, ...).
    binary,
};

/// Format option `precision` is ignored when `value` is less than 1kB
pub fn printByteSize(
    w: *Writer,
    value: u64,
    comptime units: ByteSizeUnits,
    options: std.fmt.Options,
) Error!void {
    if (value == 0) return w.alignBufferOptions("0B", options);
    // The worst case in terms of space needed is 32 bytes + 3 for the suffix.
    var buf: [std.fmt.float.min_buffer_size + 3]u8 = undefined;

    const mags_si = " kMGTPEZY";
    const mags_iec = " KMGTPEZY";

    const log2 = std.math.log2(value);
    const base = switch (units) {
        .decimal => 1000,
        .binary => 1024,
    };
    const magnitude = switch (units) {
        .decimal => @min(log2 / comptime std.math.log2(1000), mags_si.len - 1),
        .binary => @min(log2 / 10, mags_iec.len - 1),
    };
    const new_value = std.math.lossyCast(f64, value) / std.math.pow(f64, std.math.lossyCast(f64, base), std.math.lossyCast(f64, magnitude));
    const suffix = switch (units) {
        .decimal => mags_si[magnitude],
        .binary => mags_iec[magnitude],
    };

    const s = switch (magnitude) {
        0 => buf[0..std.fmt.printInt(&buf, value, 10, .lower, .{})],
        else => std.fmt.float.render(&buf, new_value, .{ .mode = .decimal, .precision = options.precision }) catch |err| switch (err) {
            error.BufferTooSmall => unreachable,
        },
    };

    var i: usize = s.len;
    if (suffix == ' ') {
        buf[i] = 'B';
        i += 1;
    } else switch (units) {
        .decimal => {
            buf[i..][0..2].* = [_]u8{ suffix, 'B' };
            i += 2;
        },
        .binary => {
            buf[i..][0..3].* = [_]u8{ suffix, 'i', 'B' };
            i += 3;
        },
    }

    return w.alignBufferOptions(buf[0..i], options);
}

// This ANY const is a workaround for: https://github.com/ziglang/zig/issues/7948
const ANY = "any";

fn stripOptionalOrErrorUnionSpec(comptime fmt: []const u8) []const u8 {
    return if (std.mem.eql(u8, fmt[1..], ANY))
        ANY
    else
        fmt[1..];
}

pub fn invalidFmtError(comptime fmt: []const u8, value: anytype) noreturn {
    @compileError("invalid format string '" ++ fmt ++ "' for type '" ++ @typeName(@TypeOf(value)) ++ "'");
}

pub fn printDurationSigned(w: *Writer, ns: i64) Error!void {
    if (ns < 0) try w.writeByte('-');
    return w.printDurationUnsigned(@abs(ns));
}

pub fn printDurationUnsigned(w: *Writer, ns: u64) Error!void {
    var ns_remaining = ns;
    inline for (.{
        .{ .ns = 365 * std.time.ns_per_day, .sep = 'y' },
        .{ .ns = std.time.ns_per_week, .sep = 'w' },
        .{ .ns = std.time.ns_per_day, .sep = 'd' },
        .{ .ns = std.time.ns_per_hour, .sep = 'h' },
        .{ .ns = std.time.ns_per_min, .sep = 'm' },
    }) |unit| {
        if (ns_remaining >= unit.ns) {
            const units = ns_remaining / unit.ns;
            try w.printInt(units, 10, .lower, .{});
            try w.writeByte(unit.sep);
            ns_remaining -= units * unit.ns;
            if (ns_remaining == 0) return;
        }
    }

    inline for (.{
        .{ .ns = std.time.ns_per_s, .sep = "s" },
        .{ .ns = std.time.ns_per_ms, .sep = "ms" },
        .{ .ns = std.time.ns_per_us, .sep = "us" },
    }) |unit| {
        const kunits = ns_remaining * 1000 / unit.ns;
        if (kunits >= 1000) {
            try w.printInt(kunits / 1000, 10, .lower, .{});
            const frac = kunits % 1000;
            if (frac > 0) {
                // Write up to 3 decimal places
                var decimal_buf = [_]u8{ '.', 0, 0, 0 };
                var inner: Writer = .fixed(decimal_buf[1..]);
                inner.printInt(frac, 10, .lower, .{ .fill = '0', .width = 3 }) catch unreachable;
                var end: usize = 4;
                while (end > 1) : (end -= 1) {
                    if (decimal_buf[end - 1] != '0') break;
                }
                try w.writeAll(decimal_buf[0..end]);
            }
            return w.writeAll(unit.sep);
        }
    }

    try w.printInt(ns_remaining, 10, .lower, .{});
    try w.writeAll("ns");
}

/// Writes number of nanoseconds according to its signed magnitude:
/// `[#y][#w][#d][#h][#m]#[.###][n|u|m]s`
/// `nanoseconds` must be an integer that coerces into `u64` or `i64`.
pub fn printDuration(w: *Writer, nanoseconds: anytype, options: std.fmt.Options) Error!void {
    // worst case: "-XXXyXXwXXdXXhXXmXX.XXXs".len = 24
    var buf: [24]u8 = undefined;
    var sub_writer: Writer = .fixed(&buf);
    if (@TypeOf(nanoseconds) == comptime_int) {
        if (nanoseconds >= 0) {
            sub_writer.printDurationUnsigned(nanoseconds) catch unreachable;
        } else {
            sub_writer.printDurationSigned(nanoseconds) catch unreachable;
        }
    } else switch (@typeInfo(@TypeOf(nanoseconds)).int.signedness) {
        .signed => sub_writer.printDurationSigned(nanoseconds) catch unreachable,
        .unsigned => sub_writer.printDurationUnsigned(nanoseconds) catch unreachable,
    }
    return w.alignBufferOptions(sub_writer.buffered(), options);
}

pub fn printHex(w: *Writer, bytes: []const u8, case: std.fmt.Case) Error!void {
    const charset = switch (case) {
        .upper => "0123456789ABCDEF",
        .lower => "0123456789abcdef",
    };
    for (bytes) |c| {
        try w.writeByte(charset[c >> 4]);
        try w.writeByte(charset[c & 15]);
    }
}

pub fn printBase64(w: *Writer, bytes: []const u8) Error!void {
    var chunker = std.mem.window(u8, bytes, 3, 3);
    var temp: [5]u8 = undefined;
    while (chunker.next()) |chunk| {
        try w.writeAll(std.base64.standard.Encoder.encode(&temp, chunk));
    }
}

/// Write a single unsigned integer as LEB128 to the given writer.
pub fn writeUleb128(w: *Writer, value: anytype) Error!void {
    try w.writeLeb128(switch (@typeInfo(@TypeOf(value))) {
        .comptime_int => @as(std.math.IntFittingRange(0, @abs(value)), value),
        .int => |value_info| switch (value_info.signedness) {
            .signed => @as(@Type(.{ .int = .{ .signedness = .unsigned, .bits = value_info.bits -| 1 } }), @intCast(value)),
            .unsigned => value,
        },
        else => comptime unreachable,
    });
}

/// Write a single signed integer as LEB128 to the given writer.
pub fn writeSleb128(w: *Writer, value: anytype) Error!void {
    try w.writeLeb128(switch (@typeInfo(@TypeOf(value))) {
        .comptime_int => @as(std.math.IntFittingRange(@min(value, -1), @max(0, value)), value),
        .int => |value_info| switch (value_info.signedness) {
            .signed => value,
            .unsigned => @as(@Type(.{ .int = .{ .signedness = .signed, .bits = value_info.bits + 1 } }), value),
        },
        else => comptime unreachable,
    });
}

/// Write a single integer as LEB128 to the given writer.
pub fn writeLeb128(w: *Writer, value: anytype) Error!void {
    const value_info = @typeInfo(@TypeOf(value)).int;
    try w.writeMultipleOf7Leb128(@as(@Type(.{ .int = .{
        .signedness = value_info.signedness,
        .bits = @max(std.mem.alignForwardAnyAlign(u16, value_info.bits, 7), 7),
    } }), value));
}

fn writeMultipleOf7Leb128(w: *Writer, value: anytype) Error!void {
    const value_info = @typeInfo(@TypeOf(value)).int;
    const Byte = packed struct(u8) { bits: u7, more: bool };
    var bytes: [@divExact(value_info.bits, 7)]Byte = undefined;
    var remaining = value;
    for (&bytes, 1..) |*byte, len| {
        const more = switch (value_info.signedness) {
            .signed => remaining >> 6 != remaining >> (value_info.bits - 1),
            .unsigned => remaining > std.math.maxInt(u7),
        };
        byte.* = .{
            .bits = @bitCast(@as(@Type(.{ .int = .{
                .signedness = value_info.signedness,
                .bits = 7,
            } }), @truncate(remaining))),
            .more = more,
        };
        if (value_info.bits > 7) remaining >>= 7;
        if (!more) return w.writeAll(@ptrCast(bytes[0..len]));
    } else unreachable;
}

test "printValue max_depth" {
    const Vec2 = struct {
        const SelfType = @This();
        x: f32,
        y: f32,

        pub fn format(self: SelfType, w: *Writer) Error!void {
            return w.print("({d:.3},{d:.3})", .{ self.x, self.y });
        }
    };
    const E = enum {
        One,
        Two,
        Three,
    };
    const TU = union(enum) {
        const SelfType = @This();
        float: f32,
        int: u32,
        ptr: ?*SelfType,
    };
    const S = struct {
        const SelfType = @This();
        a: ?*SelfType,
        tu: TU,
        e: E,
        vec: Vec2,
    };

    var inst = S{
        .a = null,
        .tu = TU{ .ptr = null },
        .e = E.Two,
        .vec = Vec2{ .x = 10.2, .y = 2.22 },
    };
    inst.a = &inst;
    inst.tu.ptr = &inst.tu;

    var buf: [1000]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try w.printValue("", .{}, inst, 0);
    try testing.expectEqualStrings(".{ ... }", w.buffered());

    w = .fixed(&buf);
    try w.printValue("", .{}, inst, 1);
    try testing.expectEqualStrings(".{ .a = .{ ... }, .tu = .{ ... }, .e = .Two, .vec = .{ ... } }", w.buffered());

    w = .fixed(&buf);
    try w.printValue("", .{}, inst, 2);
    try testing.expectEqualStrings(".{ .a = .{ .a = .{ ... }, .tu = .{ ... }, .e = .Two, .vec = .{ ... } }, .tu = .{ .ptr = .{ ... } }, .e = .Two, .vec = .{ .x = 10.2, .y = 2.22 } }", w.buffered());

    w = .fixed(&buf);
    try w.printValue("", .{}, inst, 3);
    try testing.expectEqualStrings(".{ .a = .{ .a = .{ .a = .{ ... }, .tu = .{ ... }, .e = .Two, .vec = .{ ... } }, .tu = .{ .ptr = .{ ... } }, .e = .Two, .vec = .{ .x = 10.2, .y = 2.22 } }, .tu = .{ .ptr = .{ .ptr = .{ ... } } }, .e = .Two, .vec = .{ .x = 10.2, .y = 2.22 } }", w.buffered());

    const vec: @Vector(4, i32) = .{ 1, 2, 3, 4 };
    w = .fixed(&buf);
    try w.printValue("", .{}, vec, 0);
    try testing.expectEqualStrings("{ ... }", w.buffered());

    w = .fixed(&buf);
    try w.printValue("", .{}, vec, 1);
    try testing.expectEqualStrings("{ 1, 2, 3, 4 }", w.buffered());
}

test printDuration {
    try testDurationCase("0ns", 0);
    try testDurationCase("1ns", 1);
    try testDurationCase("999ns", std.time.ns_per_us - 1);
    try testDurationCase("1us", std.time.ns_per_us);
    try testDurationCase("1.45us", 1450);
    try testDurationCase("1.5us", 3 * std.time.ns_per_us / 2);
    try testDurationCase("14.5us", 14500);
    try testDurationCase("145us", 145000);
    try testDurationCase("999.999us", std.time.ns_per_ms - 1);
    try testDurationCase("1ms", std.time.ns_per_ms + 1);
    try testDurationCase("1.5ms", 3 * std.time.ns_per_ms / 2);
    try testDurationCase("1.11ms", 1110000);
    try testDurationCase("1.111ms", 1111000);
    try testDurationCase("1.111ms", 1111100);
    try testDurationCase("999.999ms", std.time.ns_per_s - 1);
    try testDurationCase("1s", std.time.ns_per_s);
    try testDurationCase("59.999s", std.time.ns_per_min - 1);
    try testDurationCase("1m", std.time.ns_per_min);
    try testDurationCase("1h", std.time.ns_per_hour);
    try testDurationCase("1d", std.time.ns_per_day);
    try testDurationCase("1w", std.time.ns_per_week);
    try testDurationCase("1y", 365 * std.time.ns_per_day);
    try testDurationCase("1y52w23h59m59.999s", 730 * std.time.ns_per_day - 1); // 365d = 52w1
    try testDurationCase("1y1h1.001s", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_s + std.time.ns_per_ms);
    try testDurationCase("1y1h1s", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_s + 999 * std.time.ns_per_us);
    try testDurationCase("1y1h999.999us", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms - 1);
    try testDurationCase("1y1h1ms", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms);
    try testDurationCase("1y1h1ms", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms + 1);
    try testDurationCase("1y1m999ns", 365 * std.time.ns_per_day + std.time.ns_per_min + 999);
    try testDurationCase("584y49w23h34m33.709s", std.math.maxInt(u64));

    try testing.expectFmt("=======0ns", "{D:=>10}", .{0});
    try testing.expectFmt("1ns=======", "{D:=<10}", .{1});
    try testing.expectFmt("  999ns   ", "{D:^10}", .{std.time.ns_per_us - 1});
}

test printDurationSigned {
    try testDurationCaseSigned("0ns", 0);
    try testDurationCaseSigned("1ns", 1);
    try testDurationCaseSigned("-1ns", -(1));
    try testDurationCaseSigned("999ns", std.time.ns_per_us - 1);
    try testDurationCaseSigned("-999ns", -(std.time.ns_per_us - 1));
    try testDurationCaseSigned("1us", std.time.ns_per_us);
    try testDurationCaseSigned("-1us", -(std.time.ns_per_us));
    try testDurationCaseSigned("1.45us", 1450);
    try testDurationCaseSigned("-1.45us", -(1450));
    try testDurationCaseSigned("1.5us", 3 * std.time.ns_per_us / 2);
    try testDurationCaseSigned("-1.5us", -(3 * std.time.ns_per_us / 2));
    try testDurationCaseSigned("14.5us", 14500);
    try testDurationCaseSigned("-14.5us", -(14500));
    try testDurationCaseSigned("145us", 145000);
    try testDurationCaseSigned("-145us", -(145000));
    try testDurationCaseSigned("999.999us", std.time.ns_per_ms - 1);
    try testDurationCaseSigned("-999.999us", -(std.time.ns_per_ms - 1));
    try testDurationCaseSigned("1ms", std.time.ns_per_ms + 1);
    try testDurationCaseSigned("-1ms", -(std.time.ns_per_ms + 1));
    try testDurationCaseSigned("1.5ms", 3 * std.time.ns_per_ms / 2);
    try testDurationCaseSigned("-1.5ms", -(3 * std.time.ns_per_ms / 2));
    try testDurationCaseSigned("1.11ms", 1110000);
    try testDurationCaseSigned("-1.11ms", -(1110000));
    try testDurationCaseSigned("1.111ms", 1111000);
    try testDurationCaseSigned("-1.111ms", -(1111000));
    try testDurationCaseSigned("1.111ms", 1111100);
    try testDurationCaseSigned("-1.111ms", -(1111100));
    try testDurationCaseSigned("999.999ms", std.time.ns_per_s - 1);
    try testDurationCaseSigned("-999.999ms", -(std.time.ns_per_s - 1));
    try testDurationCaseSigned("1s", std.time.ns_per_s);
    try testDurationCaseSigned("-1s", -(std.time.ns_per_s));
    try testDurationCaseSigned("59.999s", std.time.ns_per_min - 1);
    try testDurationCaseSigned("-59.999s", -(std.time.ns_per_min - 1));
    try testDurationCaseSigned("1m", std.time.ns_per_min);
    try testDurationCaseSigned("-1m", -(std.time.ns_per_min));
    try testDurationCaseSigned("1h", std.time.ns_per_hour);
    try testDurationCaseSigned("-1h", -(std.time.ns_per_hour));
    try testDurationCaseSigned("1d", std.time.ns_per_day);
    try testDurationCaseSigned("-1d", -(std.time.ns_per_day));
    try testDurationCaseSigned("1w", std.time.ns_per_week);
    try testDurationCaseSigned("-1w", -(std.time.ns_per_week));
    try testDurationCaseSigned("1y", 365 * std.time.ns_per_day);
    try testDurationCaseSigned("-1y", -(365 * std.time.ns_per_day));
    try testDurationCaseSigned("1y52w23h59m59.999s", 730 * std.time.ns_per_day - 1); // 365d = 52w1d
    try testDurationCaseSigned("-1y52w23h59m59.999s", -(730 * std.time.ns_per_day - 1)); // 365d = 52w1d
    try testDurationCaseSigned("1y1h1.001s", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_s + std.time.ns_per_ms);
    try testDurationCaseSigned("-1y1h1.001s", -(365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_s + std.time.ns_per_ms));
    try testDurationCaseSigned("1y1h1s", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_s + 999 * std.time.ns_per_us);
    try testDurationCaseSigned("-1y1h1s", -(365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_s + 999 * std.time.ns_per_us));
    try testDurationCaseSigned("1y1h999.999us", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms - 1);
    try testDurationCaseSigned("-1y1h999.999us", -(365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms - 1));
    try testDurationCaseSigned("1y1h1ms", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms);
    try testDurationCaseSigned("-1y1h1ms", -(365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms));
    try testDurationCaseSigned("1y1h1ms", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms + 1);
    try testDurationCaseSigned("-1y1h1ms", -(365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms + 1));
    try testDurationCaseSigned("1y1m999ns", 365 * std.time.ns_per_day + std.time.ns_per_min + 999);
    try testDurationCaseSigned("-1y1m999ns", -(365 * std.time.ns_per_day + std.time.ns_per_min + 999));
    try testDurationCaseSigned("292y24w3d23h47m16.854s", std.math.maxInt(i64));
    try testDurationCaseSigned("-292y24w3d23h47m16.854s", std.math.minInt(i64) + 1);
    try testDurationCaseSigned("-292y24w3d23h47m16.854s", std.math.minInt(i64));

    try testing.expectFmt("=======0ns", "{D:=>10}", .{0});
    try testing.expectFmt("1ns=======", "{D:=<10}", .{1});
    try testing.expectFmt("-1ns======", "{D:=<10}", .{-(1)});
    try testing.expectFmt("  -999ns  ", "{D:^10}", .{-(std.time.ns_per_us - 1)});
}

fn testDurationCase(expected: []const u8, input: u64) !void {
    var buf: [24]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try w.printDurationUnsigned(input);
    try testing.expectEqualStrings(expected, w.buffered());
}

fn testDurationCaseSigned(expected: []const u8, input: i64) !void {
    var buf: [24]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try w.printDurationSigned(input);
    try testing.expectEqualStrings(expected, w.buffered());
}

test printInt {
    try testPrintIntCase("-1", @as(i1, -1), 10, .lower, .{});

    try testPrintIntCase("-101111000110000101001110", @as(i32, -12345678), 2, .lower, .{});
    try testPrintIntCase("-12345678", @as(i32, -12345678), 10, .lower, .{});
    try testPrintIntCase("-bc614e", @as(i32, -12345678), 16, .lower, .{});
    try testPrintIntCase("-BC614E", @as(i32, -12345678), 16, .upper, .{});

    try testPrintIntCase("12345678", @as(u32, 12345678), 10, .upper, .{});

    try testPrintIntCase("   666", @as(u32, 666), 10, .lower, .{ .width = 6 });
    try testPrintIntCase("  1234", @as(u32, 0x1234), 16, .lower, .{ .width = 6 });
    try testPrintIntCase("1234", @as(u32, 0x1234), 16, .lower, .{ .width = 1 });

    try testPrintIntCase("+42", @as(i32, 42), 10, .lower, .{ .width = 3 });
    try testPrintIntCase("-42", @as(i32, -42), 10, .lower, .{ .width = 3 });

    try testPrintIntCase("123456789123456789", @as(comptime_int, 123456789123456789), 10, .lower, .{});
}

test "printFloat with comptime_float" {
    var buf: [20]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try w.printFloat(@as(comptime_float, 1.0), std.fmt.Options.toNumber(.{}, .scientific, .lower));
    try testing.expectEqualStrings(w.buffered(), "1e0");
    try testing.expectFmt("1", "{}", .{1.0});
}

fn testPrintIntCase(expected: []const u8, value: anytype, base: u8, case: std.fmt.Case, options: std.fmt.Options) !void {
    var buffer: [100]u8 = undefined;
    var w: Writer = .fixed(&buffer);
    try w.printInt(value, base, case, options);
    try testing.expectEqualStrings(expected, w.buffered());
}

test printByteSize {
    try testing.expectFmt("file size: 42B\n", "file size: {B}\n", .{42});
    try testing.expectFmt("file size: 42B\n", "file size: {Bi}\n", .{42});
    try testing.expectFmt("file size: 63MB\n", "file size: {B}\n", .{63 * 1000 * 1000});
    try testing.expectFmt("file size: 63MiB\n", "file size: {Bi}\n", .{63 * 1024 * 1024});
    try testing.expectFmt("file size: 42B\n", "file size: {B:.2}\n", .{42});
    try testing.expectFmt("file size:       42B\n", "file size: {B:>9.2}\n", .{42});
    try testing.expectFmt("file size: 66.06MB\n", "file size: {B:.2}\n", .{63 * 1024 * 1024});
    try testing.expectFmt("file size: 60.08MiB\n", "file size: {Bi:.2}\n", .{63 * 1000 * 1000});
    try testing.expectFmt("file size: =66.06MB=\n", "file size: {B:=^9.2}\n", .{63 * 1024 * 1024});
    try testing.expectFmt("file size:   66.06MB\n", "file size: {B: >9.2}\n", .{63 * 1024 * 1024});
    try testing.expectFmt("file size: 66.06MB  \n", "file size: {B: <9.2}\n", .{63 * 1024 * 1024});
    try testing.expectFmt("file size: 0.01844674407370955ZB\n", "file size: {B}\n", .{std.math.maxInt(u64)});
}

test "bytes.hex" {
    const some_bytes = "\xCA\xFE\xBA\xBE";
    try testing.expectFmt("lowercase: cafebabe\n", "lowercase: {x}\n", .{some_bytes});
    try testing.expectFmt("uppercase: CAFEBABE\n", "uppercase: {X}\n", .{some_bytes});
    try testing.expectFmt("uppercase: CAFE\n", "uppercase: {X}\n", .{some_bytes[0..2]});
    try testing.expectFmt("lowercase: babe\n", "lowercase: {x}\n", .{some_bytes[2..]});
    const bytes_with_zeros = "\x00\x0E\xBA\xBE";
    try testing.expectFmt("lowercase: 000ebabe\n", "lowercase: {x}\n", .{bytes_with_zeros});
}

test "padding" {
    const foo: enum { foo } = .foo;
    try testing.expectFmt("tag: |foo |\n", "tag: |{t:<4}|\n", .{foo});

    const bar: error{bar} = error.bar;
    try testing.expectFmt("error: |bar |\n", "error: |{t:<4}|\n", .{bar});
}

test fixed {
    {
        var buf: [255]u8 = undefined;
        var w: Writer = .fixed(&buf);
        try w.print("{s}{s}!", .{ "Hello", "World" });
        try testing.expectEqualStrings("HelloWorld!", w.buffered());
    }

    comptime {
        var buf: [255]u8 = undefined;
        var w: Writer = .fixed(&buf);
        try w.print("{s}{s}!", .{ "Hello", "World" });
        try testing.expectEqualStrings("HelloWorld!", w.buffered());
    }
}

test "fixed output" {
    var buffer: [10]u8 = undefined;
    var w: Writer = .fixed(&buffer);

    try w.writeAll("Hello");
    try testing.expect(std.mem.eql(u8, w.buffered(), "Hello"));

    try w.writeAll("world");
    try testing.expect(std.mem.eql(u8, w.buffered(), "Helloworld"));

    try testing.expectError(error.WriteFailed, w.writeAll("!"));
    try testing.expect(std.mem.eql(u8, w.buffered(), "Helloworld"));

    w = .fixed(&buffer);

    try testing.expect(w.buffered().len == 0);

    try testing.expectError(error.WriteFailed, w.writeAll("Hello world!"));
    try testing.expect(std.mem.eql(u8, w.buffered(), "Hello worl"));
}

test "writeSplat 0 len splat larger than capacity" {
    var buf: [8]u8 = undefined;
    var w: Writer = .fixed(&buf);
    const n = try w.writeSplat(&.{"something that overflows buf"}, 0);
    try testing.expectEqual(0, n);
}

pub fn failingDrain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
    _ = w;
    _ = data;
    _ = splat;
    return error.WriteFailed;
}

pub fn failingSendFile(w: *Writer, file_reader: *File.Reader, limit: Limit) FileError!usize {
    _ = w;
    _ = file_reader;
    _ = limit;
    return error.WriteFailed;
}

pub fn failingRebase(w: *Writer, preserve: usize, capacity: usize) Error!void {
    _ = w;
    _ = preserve;
    _ = capacity;
    return error.WriteFailed;
}

pub const Discarding = struct {
    count: u64,
    writer: Writer,

    pub fn init(buffer: []u8) Discarding {
        return .{
            .count = 0,
            .writer = .{
                .vtable = &.{
                    .drain = Discarding.drain,
                    .sendFile = Discarding.sendFile,
                },
                .buffer = buffer,
            },
        };
    }

    /// Includes buffered data (no need to flush).
    pub fn fullCount(d: *const Discarding) u64 {
        return d.count + d.writer.end;
    }

    pub fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
        const d: *Discarding = @alignCast(@fieldParentPtr("writer", w));
        const slice = data[0 .. data.len - 1];
        const pattern = data[slice.len];
        var written: usize = pattern.len * splat;
        for (slice) |bytes| written += bytes.len;
        d.count += w.end + written;
        w.end = 0;
        return written;
    }

    pub fn sendFile(w: *Writer, file_reader: *File.Reader, limit: Limit) FileError!usize {
        if (File.Handle == void) return error.Unimplemented;
        switch (builtin.zig_backend) {
            else => {},
            .stage2_aarch64 => return error.Unimplemented,
        }
        const d: *Discarding = @alignCast(@fieldParentPtr("writer", w));
        d.count += w.end;
        w.end = 0;
        if (limit == .nothing) return 0;
        if (file_reader.getSize()) |size| {
            const n = limit.minInt64(size - file_reader.pos);
            if (n == 0) return error.EndOfStream;
            file_reader.seekBy(@intCast(n)) catch return error.Unimplemented;
            w.end = 0;
            d.count += n;
            return n;
        } else |_| {
            // Error is observable on `file_reader` instance, and it is better to
            // treat the file as a pipe.
            return error.Unimplemented;
        }
    }
};

/// Removes the first `n` bytes from `buffer` by shifting buffer contents,
/// returning how many bytes are left after consuming the entire buffer, or
/// zero if the entire buffer was not consumed.
///
/// Useful for `VTable.drain` function implementations to implement partial
/// drains.
pub fn consume(w: *Writer, n: usize) usize {
    if (n < w.end) {
        const remaining = w.buffer[n..w.end];
        @memmove(w.buffer[0..remaining.len], remaining);
        w.end = remaining.len;
        return 0;
    }
    defer w.end = 0;
    return n - w.end;
}

/// Shortcut for setting `end` to zero and returning zero. Equivalent to
/// calling `consume` with `end`.
pub fn consumeAll(w: *Writer) usize {
    w.end = 0;
    return 0;
}

/// For use when the `Writer` implementation can cannot offer a more efficient
/// implementation than a basic read/write loop on the file.
pub fn unimplementedSendFile(w: *Writer, file_reader: *File.Reader, limit: Limit) FileError!usize {
    _ = w;
    _ = file_reader;
    _ = limit;
    return error.Unimplemented;
}

/// When this function is called it usually means the buffer got full, so it's
/// time to return an error. However, we still need to make sure all of the
/// available buffer has been filled. Also, it may be called from `flush` in
/// which case it should return successfully.
pub fn fixedDrain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
    if (data.len == 0) return 0;
    for (data[0 .. data.len - 1]) |bytes| {
        const dest = w.buffer[w.end..];
        const len = @min(bytes.len, dest.len);
        @memcpy(dest[0..len], bytes[0..len]);
        w.end += len;
        if (bytes.len > dest.len) return error.WriteFailed;
    }
    const pattern = data[data.len - 1];
    const dest = w.buffer[w.end..];
    switch (pattern.len) {
        0 => return 0,
        1 => {
            assert(splat >= dest.len);
            @memset(dest, pattern[0]);
            w.end += dest.len;
            return error.WriteFailed;
        },
        else => {
            for (0..splat) |i| {
                const remaining = dest[i * pattern.len ..];
                const len = @min(pattern.len, remaining.len);
                @memcpy(remaining[0..len], pattern[0..len]);
                w.end += len;
                if (pattern.len > remaining.len) return error.WriteFailed;
            }
            unreachable;
        },
    }
}

pub fn unreachableDrain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
    _ = w;
    _ = data;
    _ = splat;
    unreachable;
}

pub fn unreachableRebase(w: *Writer, preserve: usize, capacity: usize) Error!void {
    _ = w;
    _ = preserve;
    _ = capacity;
    unreachable;
}

pub fn fromArrayList(array_list: *ArrayList(u8)) Writer {
    defer array_list.* = .empty;
    return .{
        .vtable = &.{
            .drain = fixedDrain,
            .flush = noopFlush,
            .rebase = failingRebase,
        },
        .buffer = array_list.allocatedSlice(),
        .end = array_list.items.len,
    };
}

pub fn toArrayList(w: *Writer) ArrayList(u8) {
    const result: ArrayList(u8) = .{
        .items = w.buffer[0..w.end],
        .capacity = w.buffer.len,
    };
    w.buffer = &.{};
    w.end = 0;
    return result;
}

/// Provides a `Writer` implementation based on calling `Hasher.update`, sending
/// all data also to an underlying `Writer`.
///
/// When using this, the underlying writer is best unbuffered because all
/// writes are passed on directly to it.
///
/// This implementation makes suboptimal buffering decisions due to being
/// generic. A better solution will involve creating a writer for each hash
/// function, where the splat buffer can be tailored to the hash implementation
/// details.
///
/// Contrast with `Hashing` which terminates the stream pipeline.
pub fn Hashed(comptime Hasher: type) type {
    return struct {
        out: *Writer,
        hasher: Hasher,
        writer: Writer,

        pub fn init(out: *Writer, buffer: []u8) @This() {
            return .initHasher(out, .{}, buffer);
        }

        pub fn initHasher(out: *Writer, hasher: Hasher, buffer: []u8) @This() {
            return .{
                .out = out,
                .hasher = hasher,
                .writer = .{
                    .buffer = buffer,
                    .vtable = &.{ .drain = @This().drain },
                },
            };
        }

        fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
            const this: *@This() = @alignCast(@fieldParentPtr("writer", w));
            const aux = w.buffered();
            const aux_n = try this.out.writeSplatHeader(aux, data, splat);
            if (aux_n < w.end) {
                this.hasher.update(w.buffer[0..aux_n]);
                const remaining = w.buffer[aux_n..w.end];
                @memmove(w.buffer[0..remaining.len], remaining);
                w.end = remaining.len;
                return 0;
            }
            this.hasher.update(aux);
            const n = aux_n - w.end;
            w.end = 0;
            var remaining: usize = n;
            for (data[0 .. data.len - 1]) |slice| {
                if (remaining <= slice.len) {
                    this.hasher.update(slice[0..remaining]);
                    return n;
                }
                remaining -= slice.len;
                this.hasher.update(slice);
            }
            const pattern = data[data.len - 1];
            assert(remaining <= splat * pattern.len);
            switch (pattern.len) {
                0 => {
                    assert(remaining == 0);
                },
                1 => {
                    var buffer: [64]u8 = undefined;
                    @memset(&buffer, pattern[0]);
                    while (remaining > 0) {
                        const update_len = @min(remaining, buffer.len);
                        this.hasher.update(buffer[0..update_len]);
                        remaining -= update_len;
                    }
                },
                else => {
                    while (remaining > 0) {
                        const update_len = @min(remaining, pattern.len);
                        this.hasher.update(pattern[0..update_len]);
                        remaining -= update_len;
                    }
                },
            }
            return n;
        }
    };
}

/// Provides a `Writer` implementation based on calling `Hasher.update`,
/// discarding all data.
///
/// This implementation makes suboptimal buffering decisions due to being
/// generic. A better solution will involve creating a writer for each hash
/// function, where the splat buffer can be tailored to the hash implementation
/// details.
///
/// The total number of bytes written is stored in `hasher`.
///
/// Contrast with `Hashed` which also passes the data to an underlying stream.
pub fn Hashing(comptime Hasher: type) type {
    return struct {
        hasher: Hasher,
        writer: Writer,

        pub fn init(buffer: []u8) @This() {
            return .initHasher(.init(.{}), buffer);
        }

        pub fn initHasher(hasher: Hasher, buffer: []u8) @This() {
            return .{
                .hasher = hasher,
                .writer = .{
                    .buffer = buffer,
                    .vtable = &.{ .drain = @This().drain },
                },
            };
        }

        fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
            const this: *@This() = @alignCast(@fieldParentPtr("writer", w));
            const hasher = &this.hasher;
            hasher.update(w.buffered());
            w.end = 0;
            var n: usize = 0;
            for (data[0 .. data.len - 1]) |slice| {
                hasher.update(slice);
                n += slice.len;
            }
            for (0..splat) |_| hasher.update(data[data.len - 1]);
            return n + splat * data[data.len - 1].len;
        }
    };
}

/// Maintains `Writer` state such that it writes to the unused capacity of an
/// array list, filling it up completely before making a call through the
/// vtable, causing a resize. Consequently, the same, optimized, non-generic
/// machine code that uses `Writer`, such as formatted printing, takes
/// the hot paths when using this API.
///
/// When using this API, it is not necessary to call `flush`.
pub const Allocating = struct {
    allocator: Allocator,
    writer: Writer,
    alignment: std.mem.Alignment,

    pub fn init(allocator: Allocator) Allocating {
        return .initAligned(allocator, .of(u8));
    }

    pub fn initAligned(allocator: Allocator, alignment: std.mem.Alignment) Allocating {
        return .{
            .allocator = allocator,
            .writer = .{
                .buffer = &.{},
                .vtable = &vtable,
            },
            .alignment = alignment,
        };
    }

    pub fn initCapacity(allocator: Allocator, capacity: usize) error{OutOfMemory}!Allocating {
        return .{
            .allocator = allocator,
            .writer = .{
                .buffer = if (capacity == 0)
                    &.{}
                else
                    (allocator.rawAlloc(capacity, .of(u8), @returnAddress()) orelse
                        return error.OutOfMemory)[0..capacity],
                .vtable = &vtable,
            },
            .alignment = .of(u8),
        };
    }

    pub fn initOwnedSlice(allocator: Allocator, slice: []u8) Allocating {
        return initOwnedSliceAligned(allocator, .of(u8), slice);
    }

    pub fn initOwnedSliceAligned(
        allocator: Allocator,
        comptime alignment: std.mem.Alignment,
        slice: []align(alignment.toByteUnits()) u8,
    ) Allocating {
        return .{
            .allocator = allocator,
            .writer = .{
                .buffer = slice,
                .vtable = &vtable,
            },
            .alignment = alignment,
        };
    }

    /// Replaces `array_list` with empty, taking ownership of the memory.
    pub fn fromArrayList(allocator: Allocator, array_list: *ArrayList(u8)) Allocating {
        return fromArrayListAligned(allocator, .of(u8), array_list);
    }

    /// Replaces `array_list` with empty, taking ownership of the memory.
    pub fn fromArrayListAligned(
        allocator: Allocator,
        comptime alignment: std.mem.Alignment,
        array_list: *std.array_list.Aligned(u8, alignment),
    ) Allocating {
        defer array_list.* = .empty;
        return .{
            .allocator = allocator,
            .writer = .{
                .vtable = &vtable,
                .buffer = array_list.allocatedSlice(),
                .end = array_list.items.len,
            },
            .alignment = alignment,
        };
    }

    const vtable: VTable = .{
        .drain = Allocating.drain,
        .sendFile = Allocating.sendFile,
        .flush = noopFlush,
        .rebase = growingRebase,
    };

    pub fn deinit(a: *Allocating) void {
        if (a.writer.buffer.len == 0) return;
        a.allocator.rawFree(a.writer.buffer, a.alignment, @returnAddress());
        a.* = undefined;
    }

    /// Returns an array list that takes ownership of the allocated memory.
    /// Resets the `Allocating` to an empty state.
    pub fn toArrayList(a: *Allocating) ArrayList(u8) {
        return toArrayListAligned(a, .of(u8));
    }

    /// Returns an array list that takes ownership of the allocated memory.
    /// Resets the `Allocating` to an empty state.
    pub fn toArrayListAligned(
        a: *Allocating,
        comptime alignment: std.mem.Alignment,
    ) std.array_list.Aligned(u8, alignment) {
        assert(a.alignment == alignment); // Required for Allocator correctness.
        const w = &a.writer;
        const result: std.array_list.Aligned(u8, alignment) = .{
            .items = @alignCast(w.buffer[0..w.end]),
            .capacity = w.buffer.len,
        };
        w.buffer = &.{};
        w.end = 0;
        return result;
    }

    pub fn ensureUnusedCapacity(a: *Allocating, additional_count: usize) Allocator.Error!void {
        const new_capacity = std.math.add(usize, a.writer.end, additional_count) catch return error.OutOfMemory;
        return ensureTotalCapacity(a, new_capacity);
    }

    pub fn ensureTotalCapacity(a: *Allocating, new_capacity: usize) Allocator.Error!void {
        // Protects growing unnecessarily since better_capacity will be larger.
        if (a.writer.buffer.len >= new_capacity) return;
        const better_capacity = ArrayList(u8).growCapacity(a.writer.buffer.len, new_capacity);
        return ensureTotalCapacityPrecise(a, better_capacity);
    }

    pub fn ensureTotalCapacityPrecise(a: *Allocating, new_capacity: usize) Allocator.Error!void {
        const old_memory = a.writer.buffer;
        if (old_memory.len >= new_capacity) return;
        assert(new_capacity != 0);
        const alignment = a.alignment;
        if (old_memory.len > 0) {
            if (a.allocator.rawRemap(old_memory, alignment, new_capacity, @returnAddress())) |new| {
                a.writer.buffer = new[0..new_capacity];
                return;
            }
        }
        const new_memory = (a.allocator.rawAlloc(new_capacity, alignment, @returnAddress()) orelse
            return error.OutOfMemory)[0..new_capacity];
        const saved = old_memory[0..a.writer.end];
        @memcpy(new_memory[0..saved.len], saved);
        if (old_memory.len != 0) a.allocator.rawFree(old_memory, alignment, @returnAddress());
        a.writer.buffer = new_memory;
    }

    pub fn toOwnedSlice(a: *Allocating) Allocator.Error![]u8 {
        const old_memory = a.writer.buffer;
        const alignment = a.alignment;
        const buffered_len = a.writer.end;

        if (old_memory.len > 0) {
            if (buffered_len == 0) {
                a.allocator.rawFree(old_memory, alignment, @returnAddress());
                a.writer.buffer = &.{};
                a.writer.end = 0;
                return old_memory[0..0];
            } else if (a.allocator.rawRemap(old_memory, alignment, buffered_len, @returnAddress())) |new| {
                a.writer.buffer = &.{};
                a.writer.end = 0;
                return new[0..buffered_len];
            }
        }

        if (buffered_len == 0)
            return a.writer.buffer[0..0];

        const new_memory = (a.allocator.rawAlloc(buffered_len, alignment, @returnAddress()) orelse
            return error.OutOfMemory)[0..buffered_len];
        @memcpy(new_memory, old_memory[0..buffered_len]);
        if (old_memory.len != 0) a.allocator.rawFree(old_memory, alignment, @returnAddress());
        a.writer.buffer = &.{};
        a.writer.end = 0;
        return new_memory;
    }

    pub fn toOwnedSliceSentinel(a: *Allocating, comptime sentinel: u8) Allocator.Error![:sentinel]u8 {
        // This addition can never overflow because `a.writer.buffer` can never occupy the whole address space.
        try ensureTotalCapacityPrecise(a, a.writer.end + 1);
        a.writer.buffer[a.writer.end] = sentinel;
        a.writer.end += 1;
        errdefer a.writer.end -= 1;
        const result = try toOwnedSlice(a);
        return result[0 .. result.len - 1 :sentinel];
    }

    pub fn written(a: *Allocating) []u8 {
        return a.writer.buffered();
    }

    pub fn shrinkRetainingCapacity(a: *Allocating, new_len: usize) void {
        a.writer.end = new_len;
    }

    pub fn clearRetainingCapacity(a: *Allocating) void {
        a.shrinkRetainingCapacity(0);
    }

    fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
        const a: *Allocating = @fieldParentPtr("writer", w);
        const pattern = data[data.len - 1];
        const splat_len = pattern.len * splat;
        const start_len = a.writer.end;
        assert(data.len != 0);
        for (data) |bytes| {
            a.ensureUnusedCapacity(bytes.len + splat_len + 1) catch return error.WriteFailed;
            @memcpy(a.writer.buffer[a.writer.end..][0..bytes.len], bytes);
            a.writer.end += bytes.len;
        }
        if (splat == 0) {
            a.writer.end -= pattern.len;
        } else switch (pattern.len) {
            0 => {},
            1 => {
                @memset(a.writer.buffer[a.writer.end..][0 .. splat - 1], pattern[0]);
                a.writer.end += splat - 1;
            },
            else => for (0..splat - 1) |_| {
                @memcpy(a.writer.buffer[a.writer.end..][0..pattern.len], pattern);
                a.writer.end += pattern.len;
            },
        }
        return a.writer.end - start_len;
    }

    fn sendFile(w: *Writer, file_reader: *File.Reader, limit: Limit) FileError!usize {
        if (File.Handle == void) return error.Unimplemented;
        if (limit == .nothing) return 0;
        const a: *Allocating = @fieldParentPtr("writer", w);
        const pos = file_reader.logicalPos();
        const additional = if (file_reader.getSize()) |size| size - pos else |_| std.atomic.cache_line;
        if (additional == 0) return error.EndOfStream;
        a.ensureUnusedCapacity(limit.minInt64(additional)) catch return error.WriteFailed;
        const dest = limit.slice(a.writer.buffer[a.writer.end..]);
        const n = try file_reader.read(dest);
        a.writer.end += n;
        return n;
    }

    fn growingRebase(w: *Writer, preserve: usize, minimum_len: usize) Error!void {
        const a: *Allocating = @fieldParentPtr("writer", w);
        const total = std.math.add(usize, preserve, minimum_len) catch return error.WriteFailed;
        a.ensureTotalCapacity(total) catch return error.WriteFailed;
        a.ensureUnusedCapacity(minimum_len) catch return error.WriteFailed;
    }

    fn testAllocating(comptime alignment: std.mem.Alignment) !void {
        var a: Allocating = .initAligned(testing.allocator, alignment);
        defer a.deinit();
        const w = &a.writer;

        const x: i32 = 42;
        const y: i32 = 1234;
        try w.print("x: {}\ny: {}\n", .{ x, y });
        const expected = "x: 42\ny: 1234\n";
        try testing.expectEqualSlices(u8, expected, a.written());

        // exercise *Aligned methods
        var l = a.toArrayListAligned(alignment);
        defer l.deinit(testing.allocator);
        try testing.expectEqualSlices(u8, expected, l.items);
        a = .fromArrayListAligned(testing.allocator, alignment, &l);
        try testing.expectEqualSlices(u8, expected, a.written());
        const slice: []align(alignment.toByteUnits()) u8 = @alignCast(try a.toOwnedSlice());
        try testing.expectEqualSlices(u8, expected, slice);
        a = .initOwnedSliceAligned(testing.allocator, alignment, slice);
        try testing.expectEqualSlices(u8, expected, a.writer.buffer);
    }

    test Allocating {
        try testAllocating(.fromByteUnits(1));
        try testAllocating(.fromByteUnits(4));
        try testAllocating(.fromByteUnits(8));
        try testAllocating(.fromByteUnits(16));
        try testAllocating(.fromByteUnits(32));
        try testAllocating(.fromByteUnits(64));
    }
};

test "discarding sendFile" {
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const file = try tmp_dir.dir.createFile("input.txt", .{ .read = true });
    defer file.close();
    var r_buffer: [256]u8 = undefined;
    var file_writer: std.fs.File.Writer = .init(file, &r_buffer);
    try file_writer.interface.writeByte('h');
    try file_writer.interface.flush();

    var file_reader = file_writer.moveToReader();
    try file_reader.seekTo(0);

    var w_buffer: [256]u8 = undefined;
    var discarding: Writer.Discarding = .init(&w_buffer);

    _ = try file_reader.interface.streamRemaining(&discarding.writer);
}

test "allocating sendFile" {
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const file = try tmp_dir.dir.createFile("input.txt", .{ .read = true });
    defer file.close();
    var r_buffer: [256]u8 = undefined;
    var file_writer: std.fs.File.Writer = .init(file, &r_buffer);
    try file_writer.interface.writeByte('h');
    try file_writer.interface.flush();

    var file_reader = file_writer.moveToReader();
    try file_reader.seekTo(0);

    var allocating: Writer.Allocating = .init(testing.allocator);
    defer allocating.deinit();

    _ = try file_reader.interface.streamRemaining(&allocating.writer);
}

test writeStruct {
    var buffer: [16]u8 = undefined;
    const S = extern struct { a: u64, b: u32, c: u32 };
    const s: S = .{ .a = 1, .b = 2, .c = 3 };
    {
        var w: Writer = .fixed(&buffer);
        try w.writeStruct(s, .little);
        try testing.expectEqualSlices(u8, &.{
            1, 0, 0, 0, 0, 0, 0, 0, //
            2, 0, 0, 0, //
            3, 0, 0, 0, //
        }, &buffer);
    }
    {
        var w: Writer = .fixed(&buffer);
        try w.writeStruct(s, .big);
        try testing.expectEqualSlices(u8, &.{
            0, 0, 0, 0, 0, 0, 0, 1, //
            0, 0, 0, 2, //
            0, 0, 0, 3, //
        }, &buffer);
    }
}

test writeSliceEndian {
    var buffer: [5]u8 align(2) = undefined;
    var w: Writer = .fixed(&buffer);
    try w.writeByte('x');
    const array: [2]u16 = .{ 0x1234, 0x5678 };
    try writeSliceEndian(&w, u16, &array, .big);
    try testing.expectEqualSlices(u8, &.{ 'x', 0x12, 0x34, 0x56, 0x78 }, &buffer);
}

test "writableSlice with fixed writer" {
    var buf: [2]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try w.writeByte(1);
    try std.testing.expectError(error.WriteFailed, w.writableSlice(2));
}
