//! To support incremental compilation, errors are stored in various places
//! so that they can be created and destroyed appropriately. This structure
//! is used to collect all the errors from the various places into one
//! convenient place for API users to consume.
//!
//! There is one special encoding for this data structure. If both arrays are
//! empty, it means there are no errors. This special encoding exists so that
//! heap allocation is not needed in the common case of no errors.

string_bytes: []const u8,
/// The first thing in this array is an `ErrorMessageList`.
extra: []const u32,

/// Special encoding when there are no errors.
pub const empty: ErrorBundle = .{
    .string_bytes = &.{},
    .extra = &.{},
};

// An index into `extra` pointing at an `ErrorMessage`.
pub const MessageIndex = enum(u32) {
    _,
};

// An index into `extra` pointing at an `SourceLocation`.
pub const SourceLocationIndex = enum(u32) {
    none = 0,
    _,
};

/// There will be a MessageIndex for each len at start.
pub const ErrorMessageList = struct {
    len: u32,
    start: u32,
    /// null-terminated string index. 0 means no compile log text.
    compile_log_text: u32,
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
/// * MessageIndex for each notes_len.
pub const ErrorMessage = struct {
    /// null terminated string index
    msg: u32,
    /// Usually one, but incremented for redundant messages.
    count: u32 = 1,
    src_loc: SourceLocationIndex = .none,
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
    src_loc: SourceLocationIndex,
};

pub fn deinit(eb: *ErrorBundle, gpa: Allocator) void {
    gpa.free(eb.string_bytes);
    gpa.free(eb.extra);
    eb.* = undefined;
}

pub fn errorMessageCount(eb: ErrorBundle) u32 {
    if (eb.extra.len == 0) return 0;
    return eb.getErrorMessageList().len;
}

pub fn getErrorMessageList(eb: ErrorBundle) ErrorMessageList {
    return eb.extraData(ErrorMessageList, 0).data;
}

pub fn getMessages(eb: ErrorBundle) []const MessageIndex {
    const list = eb.getErrorMessageList();
    return @as([]const MessageIndex, @ptrCast(eb.extra[list.start..][0..list.len]));
}

pub fn getErrorMessage(eb: ErrorBundle, index: MessageIndex) ErrorMessage {
    return eb.extraData(ErrorMessage, @intFromEnum(index)).data;
}

pub fn getSourceLocation(eb: ErrorBundle, index: SourceLocationIndex) SourceLocation {
    assert(index != .none);
    return eb.extraData(SourceLocation, @intFromEnum(index)).data;
}

pub fn getNotes(eb: ErrorBundle, index: MessageIndex) []const MessageIndex {
    const notes_len = eb.getErrorMessage(index).notes_len;
    const start = @intFromEnum(index) + @typeInfo(ErrorMessage).@"struct".fields.len;
    return @as([]const MessageIndex, @ptrCast(eb.extra[start..][0..notes_len]));
}

pub fn getCompileLogOutput(eb: ErrorBundle) [:0]const u8 {
    return nullTerminatedString(eb, getErrorMessageList(eb).compile_log_text);
}

/// Returns the requested data, as well as the new index which is at the start of the
/// trailers for the object.
fn extraData(eb: ErrorBundle, comptime T: type, index: usize) struct { data: T, end: usize } {
    const fields = @typeInfo(T).@"struct".fields;
    var i: usize = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => eb.extra[i],
            MessageIndex => @as(MessageIndex, @enumFromInt(eb.extra[i])),
            SourceLocationIndex => @as(SourceLocationIndex, @enumFromInt(eb.extra[i])),
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
    const string_bytes = eb.string_bytes;
    var end: usize = index;
    while (string_bytes[end] != 0) {
        end += 1;
    }
    return string_bytes[index..end :0];
}

pub const RenderOptions = struct {
    ttyconf: std.io.tty.Config,
    include_reference_trace: bool = true,
    include_source_line: bool = true,
    include_log_text: bool = true,
};

pub fn renderToStdErr(eb: ErrorBundle, options: RenderOptions) void {
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr();
    return renderToWriter(eb, options, stderr.writer()) catch return;
}

pub fn renderToWriter(eb: ErrorBundle, options: RenderOptions, writer: anytype) anyerror!void {
    if (eb.extra.len == 0) return;
    for (eb.getMessages()) |err_msg| {
        try renderErrorMessageToWriter(eb, options, err_msg, writer, "error", .red, 0);
    }

    if (options.include_log_text) {
        const log_text = eb.getCompileLogOutput();
        if (log_text.len != 0) {
            try writer.writeAll("\nCompile Log Output:\n");
            try writer.writeAll(log_text);
        }
    }
}

fn renderErrorMessageToWriter(
    eb: ErrorBundle,
    options: RenderOptions,
    err_msg_index: MessageIndex,
    stderr: anytype,
    kind: []const u8,
    color: std.io.tty.Color,
    indent: usize,
) anyerror!void {
    const ttyconf = options.ttyconf;
    var counting_writer = std.io.countingWriter(stderr);
    const counting_stderr = counting_writer.writer();
    const err_msg = eb.getErrorMessage(err_msg_index);
    if (err_msg.src_loc != .none) {
        const src = eb.extraData(SourceLocation, @intFromEnum(err_msg.src_loc));
        try counting_stderr.writeByteNTimes(' ', indent);
        try ttyconf.setColor(stderr, .bold);
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
        const prefix_len: usize = @intCast(counting_stderr.context.bytes_written);
        try ttyconf.setColor(stderr, .reset);
        try ttyconf.setColor(stderr, .bold);
        if (err_msg.count == 1) {
            try writeMsg(eb, err_msg, stderr, prefix_len);
            try stderr.writeByte('\n');
        } else {
            try writeMsg(eb, err_msg, stderr, prefix_len);
            try ttyconf.setColor(stderr, .dim);
            try stderr.print(" ({d} times)\n", .{err_msg.count});
        }
        try ttyconf.setColor(stderr, .reset);
        if (src.data.source_line != 0 and options.include_source_line) {
            const line = eb.nullTerminatedString(src.data.source_line);
            for (line) |b| switch (b) {
                '\t' => try stderr.writeByte(' '),
                else => try stderr.writeByte(b),
            };
            try stderr.writeByte('\n');
            // TODO basic unicode code point monospace width
            const before_caret = src.data.span_main - src.data.span_start;
            // -1 since span.main includes the caret
            const after_caret = src.data.span_end -| src.data.span_main -| 1;
            try stderr.writeByteNTimes(' ', src.data.column - before_caret);
            try ttyconf.setColor(stderr, .green);
            try stderr.writeByteNTimes('~', before_caret);
            try stderr.writeByte('^');
            try stderr.writeByteNTimes('~', after_caret);
            try stderr.writeByte('\n');
            try ttyconf.setColor(stderr, .reset);
        }
        for (eb.getNotes(err_msg_index)) |note| {
            try renderErrorMessageToWriter(eb, options, note, stderr, "note", .cyan, indent);
        }
        if (src.data.reference_trace_len > 0 and options.include_reference_trace) {
            try ttyconf.setColor(stderr, .reset);
            try ttyconf.setColor(stderr, .dim);
            try stderr.print("referenced by:\n", .{});
            var ref_index = src.end;
            for (0..src.data.reference_trace_len) |_| {
                const ref_trace = eb.extraData(ReferenceTrace, ref_index);
                ref_index = ref_trace.end;
                if (ref_trace.data.src_loc != .none) {
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
            try ttyconf.setColor(stderr, .reset);
        }
    } else {
        try ttyconf.setColor(stderr, color);
        try stderr.writeByteNTimes(' ', indent);
        try stderr.writeAll(kind);
        try stderr.writeAll(": ");
        try ttyconf.setColor(stderr, .reset);
        const msg = eb.nullTerminatedString(err_msg.msg);
        if (err_msg.count == 1) {
            try stderr.print("{s}\n", .{msg});
        } else {
            try stderr.print("{s}", .{msg});
            try ttyconf.setColor(stderr, .dim);
            try stderr.print(" ({d} times)\n", .{err_msg.count});
        }
        try ttyconf.setColor(stderr, .reset);
        for (eb.getNotes(err_msg_index)) |note| {
            try renderErrorMessageToWriter(eb, options, note, stderr, "note", .cyan, indent + 4);
        }
    }
}

/// Splits the error message up into lines to properly indent them
/// to allow for long, good-looking error messages.
///
/// This is used to split the message in `@compileError("hello\nworld")` for example.
fn writeMsg(eb: ErrorBundle, err_msg: ErrorMessage, stderr: anytype, indent: usize) !void {
    var lines = std.mem.splitScalar(u8, eb.nullTerminatedString(err_msg.msg), '\n');
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

pub const Wip = struct {
    gpa: Allocator,
    string_bytes: std.ArrayListUnmanaged(u8),
    /// The first thing in this array is a ErrorMessageList.
    extra: std.ArrayListUnmanaged(u32),
    root_list: std.ArrayListUnmanaged(MessageIndex),

    pub fn init(wip: *Wip, gpa: Allocator) !void {
        wip.* = .{
            .gpa = gpa,
            .string_bytes = .{},
            .extra = .{},
            .root_list = .{},
        };

        // So that 0 can be used to indicate a null string.
        try wip.string_bytes.append(gpa, 0);

        assert(0 == try addExtra(wip, ErrorMessageList{
            .len = 0,
            .start = 0,
            .compile_log_text = 0,
        }));
    }

    pub fn deinit(wip: *Wip) void {
        const gpa = wip.gpa;
        wip.root_list.deinit(gpa);
        wip.string_bytes.deinit(gpa);
        wip.extra.deinit(gpa);
        wip.* = undefined;
    }

    pub fn toOwnedBundle(wip: *Wip, compile_log_text: []const u8) !ErrorBundle {
        const gpa = wip.gpa;
        if (wip.root_list.items.len == 0) {
            assert(compile_log_text.len == 0);
            // Special encoding when there are no errors.
            wip.deinit();
            wip.* = .{
                .gpa = gpa,
                .string_bytes = .{},
                .extra = .{},
                .root_list = .{},
            };
            return empty;
        }

        const compile_log_str_index = if (compile_log_text.len == 0) 0 else str: {
            const str: u32 = @intCast(wip.string_bytes.items.len);
            try wip.string_bytes.ensureUnusedCapacity(gpa, compile_log_text.len + 1);
            wip.string_bytes.appendSliceAssumeCapacity(compile_log_text);
            wip.string_bytes.appendAssumeCapacity(0);
            break :str str;
        };

        wip.setExtra(0, ErrorMessageList{
            .len = @intCast(wip.root_list.items.len),
            .start = @intCast(wip.extra.items.len),
            .compile_log_text = compile_log_str_index,
        });
        try wip.extra.appendSlice(gpa, @as([]const u32, @ptrCast(wip.root_list.items)));
        wip.root_list.clearAndFree(gpa);
        return .{
            .string_bytes = try wip.string_bytes.toOwnedSlice(gpa),
            .extra = try wip.extra.toOwnedSlice(gpa),
        };
    }

    pub fn tmpBundle(wip: Wip) ErrorBundle {
        return .{
            .string_bytes = wip.string_bytes.items,
            .extra = wip.extra.items,
        };
    }

    pub fn addString(wip: *Wip, s: []const u8) Allocator.Error!u32 {
        const gpa = wip.gpa;
        const index: u32 = @intCast(wip.string_bytes.items.len);
        try wip.string_bytes.ensureUnusedCapacity(gpa, s.len + 1);
        wip.string_bytes.appendSliceAssumeCapacity(s);
        wip.string_bytes.appendAssumeCapacity(0);
        return index;
    }

    pub fn printString(wip: *Wip, comptime fmt: []const u8, args: anytype) Allocator.Error!u32 {
        const gpa = wip.gpa;
        const index: u32 = @intCast(wip.string_bytes.items.len);
        try wip.string_bytes.writer(gpa).print(fmt, args);
        try wip.string_bytes.append(gpa, 0);
        return index;
    }

    pub fn addRootErrorMessage(wip: *Wip, em: ErrorMessage) Allocator.Error!void {
        try wip.root_list.ensureUnusedCapacity(wip.gpa, 1);
        wip.root_list.appendAssumeCapacity(try addErrorMessage(wip, em));
    }

    pub fn addErrorMessage(wip: *Wip, em: ErrorMessage) Allocator.Error!MessageIndex {
        return @enumFromInt(try addExtra(wip, em));
    }

    pub fn addErrorMessageAssumeCapacity(wip: *Wip, em: ErrorMessage) MessageIndex {
        return @enumFromInt(addExtraAssumeCapacity(wip, em));
    }

    pub fn addSourceLocation(wip: *Wip, sl: SourceLocation) Allocator.Error!SourceLocationIndex {
        return @enumFromInt(try addExtra(wip, sl));
    }

    pub fn addReferenceTrace(wip: *Wip, rt: ReferenceTrace) Allocator.Error!void {
        _ = try addExtra(wip, rt);
    }

    pub fn addBundleAsNotes(wip: *Wip, other: ErrorBundle) Allocator.Error!void {
        const gpa = wip.gpa;

        try wip.string_bytes.ensureUnusedCapacity(gpa, other.string_bytes.len);
        try wip.extra.ensureUnusedCapacity(gpa, other.extra.len);

        const other_list = other.getMessages();

        // The ensureUnusedCapacity call above guarantees this.
        const notes_start = wip.reserveNotes(@intCast(other_list.len)) catch unreachable;
        for (notes_start.., other_list) |note, message| {
            // This line can cause `wip.extra.items` to be resized.
            const note_index = @intFromEnum(wip.addOtherMessage(other, message) catch unreachable);
            wip.extra.items[note] = note_index;
        }
    }

    pub fn addBundleAsRoots(wip: *Wip, other: ErrorBundle) !void {
        const gpa = wip.gpa;

        try wip.string_bytes.ensureUnusedCapacity(gpa, other.string_bytes.len);
        try wip.extra.ensureUnusedCapacity(gpa, other.extra.len);

        const other_list = other.getMessages();

        try wip.root_list.ensureUnusedCapacity(gpa, other_list.len);
        for (other_list) |other_msg| {
            // The ensureUnusedCapacity calls above guarantees this.
            wip.root_list.appendAssumeCapacity(wip.addOtherMessage(other, other_msg) catch unreachable);
        }
    }

    pub fn reserveNotes(wip: *Wip, notes_len: u32) !u32 {
        try wip.extra.ensureUnusedCapacity(wip.gpa, notes_len +
            notes_len * @typeInfo(ErrorBundle.ErrorMessage).@"struct".fields.len);
        wip.extra.items.len += notes_len;
        return @intCast(wip.extra.items.len - notes_len);
    }

    pub fn addZirErrorMessages(
        eb: *ErrorBundle.Wip,
        zir: std.zig.Zir,
        tree: std.zig.Ast,
        source: [:0]const u8,
        src_path: []const u8,
    ) !void {
        const Zir = std.zig.Zir;
        const payload_index = zir.extra[@intFromEnum(Zir.ExtraIndex.compile_errors)];
        assert(payload_index != 0);

        const header = zir.extraData(Zir.Inst.CompileErrors, payload_index);
        const items_len = header.data.items_len;
        var extra_index = header.end;
        for (0..items_len) |_| {
            const item = zir.extraData(Zir.Inst.CompileErrors.Item, extra_index);
            extra_index = item.end;
            const err_span = blk: {
                if (item.data.node != 0) {
                    break :blk tree.nodeToSpan(item.data.node);
                }
                const token_starts = tree.tokens.items(.start);
                const start = token_starts[item.data.token] + item.data.byte_offset;
                const end = start + @as(u32, @intCast(tree.tokenSlice(item.data.token).len)) - item.data.byte_offset;
                break :blk std.zig.Ast.Span{ .start = start, .end = end, .main = start };
            };
            const err_loc = std.zig.findLineColumn(source, err_span.main);

            {
                const msg = zir.nullTerminatedString(item.data.msg);
                try eb.addRootErrorMessage(.{
                    .msg = try eb.addString(msg),
                    .src_loc = try eb.addSourceLocation(.{
                        .src_path = try eb.addString(src_path),
                        .span_start = err_span.start,
                        .span_main = err_span.main,
                        .span_end = err_span.end,
                        .line = @intCast(err_loc.line),
                        .column = @intCast(err_loc.column),
                        .source_line = try eb.addString(err_loc.source_line),
                    }),
                    .notes_len = item.data.notesLen(zir),
                });
            }

            if (item.data.notes != 0) {
                const notes_start = try eb.reserveNotes(item.data.notes);
                const block = zir.extraData(Zir.Inst.Block, item.data.notes);
                const body = zir.extra[block.end..][0..block.data.body_len];
                for (notes_start.., body) |note_i, body_elem| {
                    const note_item = zir.extraData(Zir.Inst.CompileErrors.Item, body_elem);
                    const msg = zir.nullTerminatedString(note_item.data.msg);
                    const span = blk: {
                        if (note_item.data.node != 0) {
                            break :blk tree.nodeToSpan(note_item.data.node);
                        }
                        const token_starts = tree.tokens.items(.start);
                        const start = token_starts[note_item.data.token] + note_item.data.byte_offset;
                        const end = start + @as(u32, @intCast(tree.tokenSlice(note_item.data.token).len)) - item.data.byte_offset;
                        break :blk std.zig.Ast.Span{ .start = start, .end = end, .main = start };
                    };
                    const loc = std.zig.findLineColumn(source, span.main);

                    // This line can cause `wip.extra.items` to be resized.
                    const note_index = @intFromEnum(try eb.addErrorMessage(.{
                        .msg = try eb.addString(msg),
                        .src_loc = try eb.addSourceLocation(.{
                            .src_path = try eb.addString(src_path),
                            .span_start = span.start,
                            .span_main = span.main,
                            .span_end = span.end,
                            .line = @intCast(loc.line),
                            .column = @intCast(loc.column),
                            .source_line = if (loc.eql(err_loc))
                                0
                            else
                                try eb.addString(loc.source_line),
                        }),
                        .notes_len = 0, // TODO rework this function to be recursive
                    }));
                    eb.extra.items[note_i] = note_index;
                }
            }
        }
    }

    fn addOtherMessage(wip: *Wip, other: ErrorBundle, msg_index: MessageIndex) !MessageIndex {
        const other_msg = other.getErrorMessage(msg_index);
        const src_loc = try wip.addOtherSourceLocation(other, other_msg.src_loc);
        const msg = try wip.addErrorMessage(.{
            .msg = try wip.addString(other.nullTerminatedString(other_msg.msg)),
            .count = other_msg.count,
            .src_loc = src_loc,
            .notes_len = other_msg.notes_len,
        });
        const notes_start = try wip.reserveNotes(other_msg.notes_len);
        for (notes_start.., other.getNotes(msg_index)) |note, other_note| {
            wip.extra.items[note] = @intFromEnum(try wip.addOtherMessage(other, other_note));
        }
        return msg;
    }

    fn addOtherSourceLocation(
        wip: *Wip,
        other: ErrorBundle,
        index: SourceLocationIndex,
    ) !SourceLocationIndex {
        if (index == .none) return .none;
        const other_sl = other.getSourceLocation(index);

        var ref_traces: std.ArrayListUnmanaged(ReferenceTrace) = .empty;
        defer ref_traces.deinit(wip.gpa);

        if (other_sl.reference_trace_len > 0) {
            var ref_index = other.extraData(SourceLocation, @intFromEnum(index)).end;
            for (0..other_sl.reference_trace_len) |_| {
                const other_ref_trace_ed = other.extraData(ReferenceTrace, ref_index);
                const other_ref_trace = other_ref_trace_ed.data;
                ref_index = other_ref_trace_ed.end;

                const ref_trace: ReferenceTrace = if (other_ref_trace.src_loc == .none) .{
                    // sentinel ReferenceTrace does not store a string index in decl_name
                    .decl_name = other_ref_trace.decl_name,
                    .src_loc = .none,
                } else .{
                    .decl_name = try wip.addString(other.nullTerminatedString(other_ref_trace.decl_name)),
                    .src_loc = try wip.addOtherSourceLocation(other, other_ref_trace.src_loc),
                };
                try ref_traces.append(wip.gpa, ref_trace);
            }
        }

        const src_loc = try wip.addSourceLocation(.{
            .src_path = try wip.addString(other.nullTerminatedString(other_sl.src_path)),
            .line = other_sl.line,
            .column = other_sl.column,
            .span_start = other_sl.span_start,
            .span_main = other_sl.span_main,
            .span_end = other_sl.span_end,
            .source_line = if (other_sl.source_line != 0)
                try wip.addString(other.nullTerminatedString(other_sl.source_line))
            else
                0,
            .reference_trace_len = other_sl.reference_trace_len,
        });

        for (ref_traces.items) |ref_trace| {
            try wip.addReferenceTrace(ref_trace);
        }

        return src_loc;
    }

    fn addExtra(wip: *Wip, extra: anytype) Allocator.Error!u32 {
        const gpa = wip.gpa;
        const fields = @typeInfo(@TypeOf(extra)).@"struct".fields;
        try wip.extra.ensureUnusedCapacity(gpa, fields.len);
        return addExtraAssumeCapacity(wip, extra);
    }

    fn addExtraAssumeCapacity(wip: *Wip, extra: anytype) u32 {
        const fields = @typeInfo(@TypeOf(extra)).@"struct".fields;
        const result: u32 = @intCast(wip.extra.items.len);
        wip.extra.items.len += fields.len;
        setExtra(wip, result, extra);
        return result;
    }

    fn setExtra(wip: *Wip, index: usize, extra: anytype) void {
        const fields = @typeInfo(@TypeOf(extra)).@"struct".fields;
        var i = index;
        inline for (fields) |field| {
            wip.extra.items[i] = switch (field.type) {
                u32 => @field(extra, field.name),
                MessageIndex => @intFromEnum(@field(extra, field.name)),
                SourceLocationIndex => @intFromEnum(@field(extra, field.name)),
                else => @compileError("bad field type"),
            };
            i += 1;
        }
    }

    test addBundleAsRoots {
        var bundle = bundle: {
            var wip: ErrorBundle.Wip = undefined;
            try wip.init(std.testing.allocator);
            errdefer wip.deinit();

            var ref_traces: [3]ReferenceTrace = undefined;
            for (&ref_traces, 0..) |*ref_trace, i| {
                if (i == ref_traces.len - 1) {
                    // sentinel reference trace
                    ref_trace.* = .{
                        .decl_name = 3, // signifies 3 hidden references
                        .src_loc = .none,
                    };
                } else {
                    ref_trace.* = .{
                        .decl_name = try wip.addString("foo"),
                        .src_loc = try wip.addSourceLocation(.{
                            .src_path = try wip.addString("foo"),
                            .line = 1,
                            .column = 2,
                            .span_start = 3,
                            .span_main = 4,
                            .span_end = 5,
                            .source_line = 0,
                        }),
                    };
                }
            }

            const src_loc = try wip.addSourceLocation(.{
                .src_path = try wip.addString("foo"),
                .line = 1,
                .column = 2,
                .span_start = 3,
                .span_main = 4,
                .span_end = 5,
                .source_line = try wip.addString("some source code"),
                .reference_trace_len = ref_traces.len,
            });
            for (&ref_traces) |ref_trace| {
                try wip.addReferenceTrace(ref_trace);
            }

            try wip.addRootErrorMessage(ErrorMessage{
                .msg = try wip.addString("hello world"),
                .src_loc = src_loc,
                .notes_len = 1,
            });
            const i = try wip.reserveNotes(1);
            const note_index = @intFromEnum(wip.addErrorMessageAssumeCapacity(.{
                .msg = try wip.addString("this is a note"),
                .src_loc = try wip.addSourceLocation(.{
                    .src_path = try wip.addString("bar"),
                    .line = 1,
                    .column = 2,
                    .span_start = 3,
                    .span_main = 4,
                    .span_end = 5,
                    .source_line = try wip.addString("another line of source"),
                }),
            }));
            wip.extra.items[i] = note_index;

            break :bundle try wip.toOwnedBundle("");
        };
        defer bundle.deinit(std.testing.allocator);

        const ttyconf: std.io.tty.Config = .no_color;

        var bundle_buf = std.ArrayList(u8).init(std.testing.allocator);
        defer bundle_buf.deinit();
        try bundle.renderToWriter(.{ .ttyconf = ttyconf }, bundle_buf.writer());

        var copy = copy: {
            var wip: ErrorBundle.Wip = undefined;
            try wip.init(std.testing.allocator);
            errdefer wip.deinit();

            try wip.addBundleAsRoots(bundle);

            break :copy try wip.toOwnedBundle("");
        };
        defer copy.deinit(std.testing.allocator);

        var copy_buf = std.ArrayList(u8).init(std.testing.allocator);
        defer copy_buf.deinit();
        try copy.renderToWriter(.{ .ttyconf = ttyconf }, copy_buf.writer());

        try std.testing.expectEqualStrings(bundle_buf.items, copy_buf.items);
    }
};
