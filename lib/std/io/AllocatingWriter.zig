//! While it is possible to use `std.ArrayList` as the underlying writer when
//! using `std.io.BufferedWriter` by populating the `std.io.Writer` interface
//! and then using an empty buffer, it means that every use of
//! `std.io.BufferedWriter` will go through the vtable, including for
//! functions such as `writeByte`. This API instead maintains
//! `std.io.BufferedWriter` state such that it writes to the unused capacity of
//! an array list, filling it up completely before making a call through the
//! vtable, causing a resize. Consequently, the same, optimized, non-generic
//! machine code that uses `std.io.Reader`, such as formatted printing,
//! takes the hot paths when using this API.

const std = @import("../std.zig");
const AllocatingWriter = @This();
const assert = std.debug.assert;

/// This is missing the data stored in `buffered_writer`. See `getWritten` for
/// returning a slice that includes both.
written: []u8,
allocator: std.mem.Allocator,
/// When using this API, it is not necessary to call
/// `std.io.BufferedWriter.flush`.
buffered_writer: std.io.BufferedWriter,

const vtable: std.io.Writer.VTable = .{
    .writeSplat = writeSplat,
    .writeFile = writeFile,
};

/// Sets the `AllocatingWriter` to an empty state.
pub fn init(aw: *AllocatingWriter, allocator: std.mem.Allocator) void {
    aw.initOwnedSlice(allocator, &.{});
}

pub fn initCapacity(aw: *AllocatingWriter, allocator: std.mem.Allocator, capacity: usize) error{OutOfMemory}!void {
    const initial_buffer = try allocator.alloc(u8, capacity);
    aw.initOwnedSlice(allocator, initial_buffer);
}

pub fn initOwnedSlice(aw: *AllocatingWriter, allocator: std.mem.Allocator, slice: []u8) void {
    aw.* = .{
        .written = slice[0..0],
        .allocator = allocator,
        .buffered_writer = .{
            .unbuffered_writer = .{
                .context = aw,
                .vtable = &vtable,
            },
            .buffer = slice,
        },
    };
}

pub fn deinit(aw: *AllocatingWriter) void {
    const written = aw.written;
    aw.allocator.free(written.ptr[0 .. written.len + aw.buffered_writer.buffer.len]);
    aw.* = undefined;
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

pub fn toOwnedSlice(aw: *AllocatingWriter) error{OutOfMemory}![]u8 {
    var list = aw.toArrayList();
    return list.toOwnedSlice(aw.allocator);
}

pub fn toOwnedSliceSentinel(aw: *AllocatingWriter, comptime sentinel: u8) error{OutOfMemory}![:sentinel]u8 {
    const gpa = aw.allocator;
    var list = toArrayList(aw);
    return list.toOwnedSliceSentinel(gpa, sentinel);
}

fn setArrayList(aw: *AllocatingWriter, list: std.ArrayListUnmanaged(u8)) void {
    aw.written = list.items;
    aw.buffered_writer.buffer = list.unusedCapacitySlice();
}

pub fn getWritten(aw: *AllocatingWriter) []u8 {
    const bw = &aw.buffered_writer;
    const end = aw.buffered_writer.end;
    const written = aw.written.ptr[0 .. aw.written.len + end];
    aw.written = written;
    bw.buffer = bw.buffer[end..];
    bw.end = 0;
    return written;
}

pub fn shrinkRetainingCapacity(aw: *AllocatingWriter, new_len: usize) void {
    const bw = &aw.buffered_writer;
    bw.buffer = aw.written.ptr[new_len .. aw.written.len + bw.buffer.len];
    bw.end = 0;
    aw.written.len = new_len;
}

pub fn clearRetainingCapacity(aw: *AllocatingWriter) void {
    aw.shrinkRetainingCapacity(0);
}

fn writeSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) std.io.Writer.Error!usize {
    assert(data.len != 0);
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
    const rest = if (splat == 0) data[1 .. data.len - 1] else data[1..];
    const pattern = data[data.len - 1];
    const remaining_splat = splat - 1;
    var new_capacity: usize = list.capacity + pattern.len * remaining_splat;
    for (rest) |bytes| new_capacity += bytes.len;
    list.ensureTotalCapacity(aw.allocator, new_capacity + 1) catch return error.WriteFailed;
    for (rest) |bytes| list.appendSliceAssumeCapacity(bytes);
    if (pattern.len == 1) {
        list.appendNTimesAssumeCapacity(pattern[0], remaining_splat);
    } else {
        for (0..remaining_splat) |_| list.appendSliceAssumeCapacity(pattern);
    }
    aw.written = list.items;
    bw.buffer = list.unusedCapacitySlice();
    return list.items.len - start_len;
}

fn writeFile(
    context: ?*anyopaque,
    file_reader: *std.fs.File.Reader,
    limit: std.io.Limit,
    headers_and_trailers_full: []const []const u8,
    headers_len_full: usize,
) std.io.Writer.FileError!usize {
    if (std.fs.File.Handle == void) return error.Unimplemented;
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
    const pos = file_reader.pos;

    const additional = if (file_reader.getSize()) |size| size - pos else |_| std.atomic.cache_line;
    var new_capacity: usize = list.capacity + limit.minInt(additional);
    for (headers_and_trailers) |bytes| new_capacity += bytes.len;
    list.ensureTotalCapacity(gpa, new_capacity) catch return error.WriteFailed;
    for (headers_and_trailers[0..headers_len]) |bytes| list.appendSliceAssumeCapacity(bytes);
    const dest = limit.slice(list.items.ptr[list.items.len..list.capacity]);
    const n = file_reader.read(dest) catch |err| switch (err) {
        error.ReadFailed => return error.ReadFailed,
        error.EndOfStream => 0,
    };
    const is_end = if (file_reader.getSize()) |size| n >= size - pos else |_| n == 0;
    if (is_end) {
        new_capacity = list.capacity;
        for (trailers) |bytes| new_capacity += bytes.len;
        list.ensureTotalCapacity(gpa, new_capacity) catch return error.WriteFailed;
        for (trailers) |bytes| list.appendSliceAssumeCapacity(bytes);
    } else {
        list.items.len += n;
    }
    return list.items.len - start_len;
}

test AllocatingWriter {
    var aw: AllocatingWriter = undefined;
    aw.init(std.testing.allocator);
    defer aw.deinit();
    const bw = &aw.buffered_writer;

    const x: i32 = 42;
    const y: i32 = 1234;
    try bw.print("x: {}\ny: {}\n", .{ x, y });

    try std.testing.expectEqualSlices(u8, "x: 42\ny: 1234\n", aw.getWritten());
}
