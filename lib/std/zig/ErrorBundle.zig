//! To support incremental compilation, errors are stored in various places
//! so that they can be created and destroyed appropriately. This structure
//! is used to collect all the errors from the various places into one
//! convenient place for API users to consume.

string_bytes: std.ArrayListUnmanaged(u8),
/// The first thing in this array is a ErrorMessageListIndex.
extra: std.ArrayListUnmanaged(u32),

// An index into `extra` pointing at an `ErrorMessage`.
pub const MessageIndex = enum(u32) {
    _,
};

/// After the header is:
/// * string_bytes
/// * extra (little endian)
pub const Header = struct {
    string_bytes_len: u32,
    extra_len: u32,
};

/// Trailing: ErrorMessage for each len
pub const ErrorMessageList = struct {
    len: u32,
    start: u32,
};

/// Trailing:
/// * ReferenceTrace for each reference_trace_len
pub const SourceLocation = struct {
    /// null terminated string index
    src_path: u32,
    line: u32,
    column: u32,
    /// byte offset of starting token
    span_start: u32,
    /// byte offset of main error location
    span_main: u32,
    /// byte offset of end of last token
    span_end: u32,
    /// null terminated string index, possibly null.
    /// Does not include the trailing newline.
    source_line: u32 = 0,
    reference_trace_len: u32 = 0,
};

/// Trailing:
/// * ErrorMessage for each notes_len.
pub const ErrorMessage = struct {
    /// null terminated string index
    msg: u32,
    /// Usually one, but incremented for redundant messages.
    count: u32 = 1,
    /// 0 or the index into extra of a SourceLocation
    src_loc: u32 = 0,
    notes_len: u32 = 0,
};

pub const ReferenceTrace = struct {
    /// null terminated string index
    /// Except for the sentinel ReferenceTrace element, in which case:
    /// * 0 means remaining references hidden
    /// * >0 means N references hidden
    decl_name: u32,
    /// Index into extra of a SourceLocation
    /// If this is 0, this is the sentinel ReferenceTrace element.
    src_loc: u32,
};

pub fn init(eb: *ErrorBundle, gpa: Allocator) !void {
    eb.* = .{
        .string_bytes = .{},
        .extra = .{},
    };

    // So that 0 can be used to indicate a null string.
    try eb.string_bytes.append(gpa, 0);

    _ = try addExtra(eb, gpa, ErrorMessageList{
        .len = 0,
        .start = 0,
    });
}

pub fn deinit(eb: *ErrorBundle, gpa: Allocator) void {
    eb.string_bytes.deinit(gpa);
    eb.extra.deinit(gpa);
    eb.* = undefined;
}

pub fn addString(eb: *ErrorBundle, gpa: Allocator, s: []const u8) !u32 {
    const index = @intCast(u32, eb.string_bytes.items.len);
    try eb.string_bytes.ensureUnusedCapacity(gpa, s.len + 1);
    eb.string_bytes.appendSliceAssumeCapacity(s);
    eb.string_bytes.appendAssumeCapacity(0);
    return index;
}

pub fn printString(eb: *ErrorBundle, gpa: Allocator, comptime fmt: []const u8, args: anytype) !u32 {
    const index = @intCast(u32, eb.string_bytes.items.len);
    try eb.string_bytes.writer(gpa).print(fmt, args);
    try eb.string_bytes.append(gpa, 0);
    return index;
}

pub fn addErrorMessage(eb: *ErrorBundle, gpa: Allocator, em: ErrorMessage) !void {
    if (eb.errorMessageCount() == 0) {
        eb.setStartIndex(@intCast(u32, eb.extra.items.len));
    }
    _ = try addExtra(eb, gpa, em);
}

pub fn addSourceLocation(eb: *ErrorBundle, gpa: Allocator, sl: SourceLocation) !u32 {
    return addExtra(eb, gpa, sl);
}

pub fn addReferenceTrace(eb: *ErrorBundle, gpa: Allocator, rt: ReferenceTrace) !void {
    _ = try addExtra(eb, gpa, rt);
}

pub fn addBundle(eb: *ErrorBundle, gpa: Allocator, other: ErrorBundle) !void {
    // Skip over the initial ErrorMessageList len field.
    const root_fields_len = @typeInfo(ErrorMessageList).Struct.fields.len;
    const other_list = other.extraData(ErrorMessageList, 0).data;
    const other_extra = other.extra.items[root_fields_len..];

    try eb.string_bytes.ensureUnusedCapacity(gpa, other.string_bytes.items.len);
    try eb.extra.ensureUnusedCapacity(gpa, other_extra.len);

    const new_string_base = @intCast(u32, eb.string_bytes.items.len);
    const new_data_base = @intCast(u32, eb.extra.items.len - root_fields_len);

    eb.string_bytes.appendSliceAssumeCapacity(other.string_bytes.items);
    eb.extra.appendSliceAssumeCapacity(other_extra);

    // Now we must offset the string indexes and extra indexes of the newly
    // added extra.
    var index = new_data_base + other_list.start;
    for (0..other_list.len) |_| {
        index = try patchMessage(eb, index, new_string_base, new_data_base);
    }
}

fn patchMessage(eb: *ErrorBundle, msg_idx: usize, new_string_base: u32, new_data_base: u32) !u32 {
    var msg = eb.extraData(ErrorMessage, msg_idx);
    if (msg.data.msg != 0) msg.data.msg += new_string_base;
    if (msg.data.src_loc != 0) msg.data.src_loc += new_data_base;
    eb.setExtra(msg_idx, msg.data);

    try patchSrcLoc(eb, msg.data.src_loc, new_string_base, new_data_base);

    var index = @intCast(u32, msg.end);
    for (0..msg.data.notes_len) |_| {
        index = try patchMessage(eb, index, new_string_base, new_data_base);
    }
    return index;
}

fn patchSrcLoc(eb: *ErrorBundle, idx: usize, new_string_base: u32, new_data_base: u32) !void {
    if (idx == 0) return;

    var src_loc = eb.extraData(SourceLocation, idx);
    if (src_loc.data.src_path != 0) src_loc.data.src_path += new_string_base;
    if (src_loc.data.source_line != 0) src_loc.data.source_line += new_string_base;
    eb.setExtra(idx, src_loc.data);

    var index = src_loc.end;
    for (0..src_loc.data.reference_trace_len) |_| {
        var ref_trace = eb.extraData(ReferenceTrace, index);
        if (ref_trace.data.decl_name != 0) ref_trace.data.decl_name += new_string_base;
        if (ref_trace.data.src_loc != 0) ref_trace.data.src_loc += new_data_base;
        eb.setExtra(index, ref_trace.data);
        try patchSrcLoc(eb, ref_trace.data.src_loc, new_string_base, new_data_base);
        index = ref_trace.end;
    }
}

fn addExtra(eb: *ErrorBundle, gpa: Allocator, extra: anytype) Allocator.Error!u32 {
    const fields = @typeInfo(@TypeOf(extra)).Struct.fields;
    try eb.extra.ensureUnusedCapacity(gpa, fields.len);
    return addExtraAssumeCapacity(eb, extra);
}

fn addExtraAssumeCapacity(eb: *ErrorBundle, extra: anytype) u32 {
    const fields = @typeInfo(@TypeOf(extra)).Struct.fields;
    const result = @intCast(u32, eb.extra.items.len);
    eb.extra.items.len += fields.len;
    setExtra(eb, result, extra);
    return result;
}

fn setExtra(eb: *ErrorBundle, index: usize, extra: anytype) void {
    const fields = @typeInfo(@TypeOf(extra)).Struct.fields;
    var i = index;
    inline for (fields) |field| {
        eb.extra.items[i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
        i += 1;
    }
}

pub fn errorMessageCount(eb: ErrorBundle) u32 {
    return eb.extra.items[0];
}

pub fn setErrorMessageCount(eb: *ErrorBundle, count: u32) void {
    eb.extra.items[0] = count;
}

pub fn incrementCount(eb: *ErrorBundle, delta: u32) void {
    eb.extra.items[0] += delta;
}

pub fn getStartIndex(eb: ErrorBundle) u32 {
    return eb.extra.items[1];
}

pub fn setStartIndex(eb: *ErrorBundle, index: u32) void {
    eb.extra.items[1] = index;
}

pub fn getErrorMessage(eb: ErrorBundle, index: MessageIndex) ErrorMessage {
    return eb.extraData(ErrorMessage, @enumToInt(index)).data;
}

pub fn getSourceLocation(eb: ErrorBundle, index: u32) SourceLocation {
    assert(index != 0);
    return eb.extraData(SourceLocation, index).data;
}

/// Returns the requested data, as well as the new index which is at the start of the
/// trailers for the object.
fn extraData(eb: ErrorBundle, comptime T: type, index: usize) struct { data: T, end: usize } {
    const fields = @typeInfo(T).Struct.fields;
    var i: usize = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => eb.extra.items[i],
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return .{
        .data = result,
        .end = i,
    };
}

/// Given an index into `string_bytes` returns the null-terminated string found there.
pub fn nullTerminatedString(eb: ErrorBundle, index: usize) [:0]const u8 {
    const string_bytes = eb.string_bytes.items;
    var end: usize = index;
    while (string_bytes[end] != 0) {
        end += 1;
    }
    return string_bytes[index..end :0];
}

pub fn renderToStdErr(eb: ErrorBundle, ttyconf: std.debug.TTY.Config) void {
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    const stderr = std.io.getStdErr();
    return renderToWriter(eb, ttyconf, stderr.writer()) catch return;
}

pub fn renderToWriter(
    eb: ErrorBundle,
    ttyconf: std.debug.TTY.Config,
    writer: anytype,
) anyerror!void {
    const list = eb.extraData(ErrorMessageList, 0).data;
    var index: usize = list.start;
    for (0..list.len) |_| {
        const err_msg = eb.extraData(ErrorMessage, index);
        index = try renderErrorMessageToWriter(eb, err_msg.data, err_msg.end, ttyconf, writer, "error", .Red, 0);
    }
}

fn renderErrorMessageToWriter(
    eb: ErrorBundle,
    err_msg: ErrorMessage,
    end_index: usize,
    ttyconf: std.debug.TTY.Config,
    stderr: anytype,
    kind: []const u8,
    color: std.debug.TTY.Color,
    indent: usize,
) anyerror!usize {
    var counting_writer = std.io.countingWriter(stderr);
    const counting_stderr = counting_writer.writer();
    if (err_msg.src_loc != 0) {
        const src = eb.extraData(SourceLocation, err_msg.src_loc);
        try counting_stderr.writeByteNTimes(' ', indent);
        try ttyconf.setColor(stderr, .Bold);
        try counting_stderr.print("{s}:{d}:{d}: ", .{
            eb.nullTerminatedString(src.data.src_path),
            src.data.line + 1,
            src.data.column + 1,
        });
        try ttyconf.setColor(stderr, color);
        try counting_stderr.writeAll(kind);
        try counting_stderr.writeAll(": ");
        // This is the length of the part before the error message:
        // e.g. "file.zig:4:5: error: "
        const prefix_len = @intCast(usize, counting_stderr.context.bytes_written);
        try ttyconf.setColor(stderr, .Reset);
        try ttyconf.setColor(stderr, .Bold);
        if (err_msg.count == 1) {
            try writeMsg(eb, err_msg, stderr, prefix_len);
            try stderr.writeByte('\n');
        } else {
            try writeMsg(eb, err_msg, stderr, prefix_len);
            try ttyconf.setColor(stderr, .Dim);
            try stderr.print(" ({d} times)\n", .{err_msg.count});
        }
        try ttyconf.setColor(stderr, .Reset);
        if (src.data.source_line != 0) {
            const line = eb.nullTerminatedString(src.data.source_line);
            for (line) |b| switch (b) {
                '\t' => try stderr.writeByte(' '),
                else => try stderr.writeByte(b),
            };
            try stderr.writeByte('\n');
            // TODO basic unicode code point monospace width
            const before_caret = src.data.span_main - src.data.span_start;
            // -1 since span.main includes the caret
            const after_caret = src.data.span_end - src.data.span_main -| 1;
            try stderr.writeByteNTimes(' ', src.data.column - before_caret);
            try ttyconf.setColor(stderr, .Green);
            try stderr.writeByteNTimes('~', before_caret);
            try stderr.writeByte('^');
            try stderr.writeByteNTimes('~', after_caret);
            try stderr.writeByte('\n');
            try ttyconf.setColor(stderr, .Reset);
        }
        var index = end_index;
        for (0..err_msg.notes_len) |_| {
            const note = eb.extraData(ErrorMessage, index);
            index = try renderErrorMessageToWriter(eb, note.data, note.end, ttyconf, stderr, "note", .Cyan, indent);
        }
        if (src.data.reference_trace_len > 0) {
            try ttyconf.setColor(stderr, .Reset);
            try ttyconf.setColor(stderr, .Dim);
            try stderr.print("referenced by:\n", .{});
            var ref_index = src.end;
            for (0..src.data.reference_trace_len) |_| {
                const ref_trace = eb.extraData(ReferenceTrace, ref_index);
                ref_index = ref_trace.end;
                if (ref_trace.data.src_loc != 0) {
                    const ref_src = eb.getSourceLocation(ref_trace.data.src_loc);
                    try stderr.print("    {s}: {s}:{d}:{d}\n", .{
                        eb.nullTerminatedString(ref_trace.data.decl_name),
                        eb.nullTerminatedString(ref_src.src_path),
                        ref_src.line + 1,
                        ref_src.column + 1,
                    });
                } else if (ref_trace.data.decl_name != 0) {
                    const count = ref_trace.data.decl_name;
                    try stderr.print(
                        "    {d} reference(s) hidden; use '-freference-trace={d}' to see all references\n",
                        .{ count, count + src.data.reference_trace_len - 1 },
                    );
                } else {
                    try stderr.print(
                        "    remaining reference traces hidden; use '-freference-trace' to see all reference traces\n",
                        .{},
                    );
                }
            }
            try stderr.writeByte('\n');
            try ttyconf.setColor(stderr, .Reset);
        }
        return index;
    } else {
        try ttyconf.setColor(stderr, color);
        try stderr.writeByteNTimes(' ', indent);
        try stderr.writeAll(kind);
        try stderr.writeAll(": ");
        try ttyconf.setColor(stderr, .Reset);
        const msg = eb.nullTerminatedString(err_msg.msg);
        if (err_msg.count == 1) {
            try stderr.print("{s}\n", .{msg});
        } else {
            try stderr.print("{s}", .{msg});
            try ttyconf.setColor(stderr, .Dim);
            try stderr.print(" ({d} times)\n", .{err_msg.count});
        }
        try ttyconf.setColor(stderr, .Reset);
        var index = end_index;
        for (0..err_msg.notes_len) |_| {
            const note = eb.extraData(ErrorMessage, index);
            index = try renderErrorMessageToWriter(eb, note.data, note.end, ttyconf, stderr, "note", .Cyan, indent + 4);
        }
        return index;
    }
}

/// Splits the error message up into lines to properly indent them
/// to allow for long, good-looking error messages.
///
/// This is used to split the message in `@compileError("hello\nworld")` for example.
fn writeMsg(eb: ErrorBundle, err_msg: ErrorMessage, stderr: anytype, indent: usize) !void {
    var lines = std.mem.split(u8, eb.nullTerminatedString(err_msg.msg), "\n");
    while (lines.next()) |line| {
        try stderr.writeAll(line);
        if (lines.index == null) break;
        try stderr.writeByte('\n');
        try stderr.writeByteNTimes(' ', indent);
    }
}

const std = @import("std");
const ErrorBundle = @This();
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
