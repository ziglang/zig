//! TODO rename to AllocatingWriter.
//! While it is possible to use `std.ArrayList` as the underlying writer when
//! using `std.io.BufferedWriter` by populating the `std.io.Writer` interface
//! and then using an empty buffer, it means that every use of
//! `std.io.BufferedWriter` will go through the vtable, including for
//! functions such as `writeByte`. This API instead maintains
//! `std.io.BufferedWriter` state such that it writes to the unused capacity of
//! an array list, filling it up completely before making a call through the
//! vtable, causing a resize. Consequently, the same, optimized, non-generic
//! machine code that uses `std.io.BufferedReader`, such as formatted printing,
//! takes the hot paths when using this API.

const std = @import("../std.zig");
const AllocatingWriter = @This();
const assert = std.debug.assert;

/// This is missing the data stored in `buffered_writer`. See `getWritten` for
/// returning a slice that includes both.
written: []u8,
allocator: std.mem.Allocator,
buffered_writer: std.io.BufferedWriter,

const vtable: std.io.Writer.VTable = .{
    .writeSplat = writeSplat,
    .writeFile = writeFile,
};

/// Sets the `AllocatingWriter` to an empty state.
pub fn init(aw: *AllocatingWriter, allocator: std.mem.Allocator) *std.io.BufferedWriter {
    aw.* = .{
        .written = &.{},
        .allocator = allocator,
        .buffered_writer = .{
            .unbuffered_writer = .{
                .context = aw,
                .vtable = &vtable,
            },
            .buffer = &.{},
        },
    };
    return &aw.buffered_writer;
}

/// Replaces `array_list` with empty, taking ownership of the memory.
pub fn fromArrayList(
    aw: *AllocatingWriter,
    allocator: std.mem.Allocator,
    array_list: *std.ArrayListUnmanaged(u8),
) *std.io.BufferedWriter {
    aw.* = .{
        .written = array_list.items,
        .allocator = allocator,
        .buffered_writer = .{
            .unbuffered_writer = .{
                .context = aw,
                .vtable = &vtable,
            },
            .buffer = array_list.unusedCapacitySlice(),
        },
    };
    array_list.* = .empty;
    return &aw.buffered_writer;
}

/// Returns an array list that takes ownership of the allocated memory.
/// Resets the `AllocatingWriter` to an empty state.
pub fn toArrayList(aw: *AllocatingWriter) std.ArrayListUnmanaged(u8) {
    const bw = &aw.buffered_writer;
    const written = aw.written;
    const result: std.ArrayListUnmanaged(u8) = .{
        .items = written.ptr[0 .. written.len + bw.end],
        .capacity = written.len + bw.buffer.len,
    };
    aw.written = &.{};
    bw.buffer = &.{};
    bw.end = 0;
    return result;
}

fn setArrayList(aw: *AllocatingWriter, list: std.ArrayListUnmanaged(u8)) void {
    aw.written = list.items;
    aw.buffered_writer.buffer = list.unusedCapacitySlice();
}

pub fn getWritten(aw: *AllocatingWriter) []u8 {
    const bw = &aw.buffered_writer;
    const end = aw.buffered_writer.end;
    const result = aw.written.ptr[0 .. aw.written.len + end];
    bw.buffer = bw.buffer[end..];
    bw.end = 0;
    return result;
}

pub fn clearRetainingCapacity(aw: *AllocatingWriter) void {
    const bw = &aw.buffered_writer;
    bw.buffer = aw.written.ptr[0 .. aw.written.len + bw.buffer.len];
    bw.end = 0;
    aw.written.len = 0;
}

fn writeSplat(context: *anyopaque, data: []const []const u8, splat: usize) anyerror!usize {
    const aw: *AllocatingWriter = @alignCast(@ptrCast(context));
    const start_len = aw.written.len;
    const bw = &aw.buffered_writer;
    const skip_first = data[0].ptr == aw.written.ptr + start_len;
    const items_len = if (skip_first) start_len + data[0].len else start_len;
    var list: std.ArrayListUnmanaged(u8) = .{
        .items = aw.written.ptr[0..items_len],
        .capacity = start_len + bw.buffer.len,
    };
    defer setArrayList(aw, list);
    const rest = data[1 .. data.len - 1];
    const pattern = data[data.len - 1];
    var new_capacity: usize = list.capacity + pattern.len * splat;
    for (rest) |bytes| new_capacity += bytes.len;
    try list.ensureTotalCapacity(aw.allocator, new_capacity + 1);
    for (rest) |bytes| list.appendSliceAssumeCapacity(bytes);
    appendPatternAssumeCapacity(&list, pattern, splat);
    aw.written = list.items;
    bw.buffer = list.unusedCapacitySlice();
    return list.items.len - start_len;
}

fn appendPatternAssumeCapacity(list: *std.ArrayListUnmanaged(u8), pattern: []const u8, splat: usize) void {
    if (pattern.len == 1) {
        list.appendNTimesAssumeCapacity(pattern[0], splat);
    } else {
        for (0..splat) |_| list.appendSliceAssumeCapacity(pattern);
    }
}

fn writeFile(
    context: *anyopaque,
    file: std.fs.File,
    offset: u64,
    len: std.io.Writer.VTable.FileLen,
    headers_and_trailers_full: []const []const u8,
    headers_len_full: usize,
) anyerror!usize {
    const aw: *AllocatingWriter = @alignCast(@ptrCast(context));
    const gpa = aw.allocator;
    var list = aw.toArrayList();
    defer setArrayList(aw, list);
    const start_len = list.items.len;
    const headers_and_trailers, const headers_len = if (headers_len_full >= 1) b: {
        assert(headers_and_trailers_full[0].ptr == list.items.ptr + start_len);
        list.items.len += headers_and_trailers_full[0].len;
        break :b .{ headers_and_trailers_full[1..], headers_len_full - 1 };
    } else .{ headers_and_trailers_full, headers_len_full };
    const trailers = headers_and_trailers[headers_len..];
    if (len == .entire_file) {
        var new_capacity: usize = list.capacity + std.atomic.cache_line;
        for (headers_and_trailers) |bytes| new_capacity += bytes.len;
        try list.ensureTotalCapacity(gpa, new_capacity);
        for (headers_and_trailers[0..headers_len]) |bytes| list.appendSliceAssumeCapacity(bytes);
        const dest = list.items.ptr[list.items.len..list.capacity];
        const n = try file.pread(dest, offset);
        if (n == 0) {
            new_capacity = list.capacity;
            for (trailers) |bytes| new_capacity += bytes.len;
            try list.ensureTotalCapacity(gpa, new_capacity);
            for (trailers) |bytes| list.appendSliceAssumeCapacity(bytes);
            return list.items.len - start_len;
        }
        list.items.len += n;
        return list.items.len - start_len;
    }
    var new_capacity: usize = list.capacity + len.int();
    for (headers_and_trailers) |bytes| new_capacity += bytes.len;
    try list.ensureTotalCapacity(gpa, new_capacity);
    for (headers_and_trailers[0..headers_len]) |bytes| list.appendSliceAssumeCapacity(bytes);
    const dest = list.items.ptr[list.items.len..][0..len.int()];
    const n = try file.pread(dest, offset);
    list.items.len += n;
    if (n < dest.len) {
        return list.items.len - start_len;
    }
    for (trailers) |bytes| list.appendSliceAssumeCapacity(bytes);
    return list.items.len - start_len;
}
