//! The straightforward way to use `std.ArrayList` as the underlying writer
//! when using `std.io.BufferedWriter` is to populate the `std.io.Writer`
//! interface and then use an empty buffer. However, this means that every use
//! of `std.io.BufferedWriter` will go through the vtable, including for
//! functions such as `writeByte`. This API instead maintains
//! `std.io.BufferedWriter` state such that it writes to the unused capacity of
//! the array list, filling it up completely before making a call through the
//! vtable, causing a resize. Consequently, the same, optimized, non-generic
//! machine code that uses `std.io.BufferedReader`, such as formatted printing,
//! is also used when the underlying writer is backed by `std.ArrayList`.

const std = @import("../std.zig");
const ArrayListWriter = @This();
const assert = std.debug.assert;

items: []u8,
allocator: std.mem.Allocator,
buffered_writer: std.io.BufferedWriter,

/// Replaces `array_list` with empty, taking ownership of the memory.
pub fn fromOwned(
    alw: *ArrayListWriter,
    allocator: std.mem.Allocator,
    array_list: *std.ArrayListUnmanaged(u8),
) *std.io.BufferedWriter {
    alw.* = .{
        .allocated_slice = array_list.items,
        .allocator = allocator,
        .buffered_writer = .{
            .unbuffered_writer = .{
                .context = alw,
                .vtable = &.{
                    .writev = writev,
                    .writeFile = writeFile,
                },
            },
            .buffer = array_list.unusedCapacitySlice(),
        },
    };
    array_list.* = .empty;
    return &alw.buffered_writer;
}

/// Returns the memory back that was borrowed with `fromOwned`.
pub fn toOwned(alw: *ArrayListWriter) std.ArrayListUnmanaged(u8) {
    const end = alw.buffered_writer.end;
    const result: std.ArrayListUnmanaged(u8) = .{
        .items = alw.items.ptr[0 .. alw.items.len + end],
        .capacity = alw.buffered_writer.buffer.len - end,
    };
    alw.* = undefined;
    return result;
}

fn writev(context: *anyopaque, data: []const []const u8) anyerror!usize {
    const alw: *ArrayListWriter = @alignCast(@ptrCast(context));
    const start_len = alw.items.len;
    const bw = &alw.buffered_writer;
    assert(data[0].ptr == alw.items.ptr + start_len);
    const bw_end = data[0].len;
    var list: std.ArrayListUnmanaged(u8) = .{
        .items = alw.items.ptr[0 .. start_len + bw_end],
        .capacity = bw.buffer.len - bw_end,
    };
    const rest = data[1..];
    var new_capacity: usize = list.capacity;
    for (rest) |bytes| new_capacity += bytes.len;
    try list.ensureTotalCapacity(alw.allocator, new_capacity + 1);
    for (rest) |bytes| list.appendSliceAssumeCapacity(bytes);
    alw.items = list.items;
    bw.buffer = list.unusedCapacitySlice();
    return list.items.len - start_len;
}

fn writeFile(
    context: *anyopaque,
    file: std.fs.File,
    offset: u64,
    len: std.io.Writer.VTable.FileLen,
    headers_and_trailers_full: []const []const u8,
    headers_len_full: usize,
) anyerror!usize {
    const alw: *ArrayListWriter = @alignCast(@ptrCast(context));
    const list = alw.array_list;
    const bw = &alw.buffered_writer;
    const start_len = list.items.len;
    const headers_and_trailers, const headers_len = if (headers_len_full >= 1) b: {
        assert(headers_and_trailers_full[0].ptr == list.items.ptr + start_len);
        list.items.len += headers_and_trailers_full[0].len;
        break :b .{ headers_and_trailers_full[1..], headers_len_full - 1 };
    } else .{ headers_and_trailers_full, headers_len_full };
    const gpa = alw.allocator;
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
            bw.buffer = list.unusedCapacitySlice();
            return list.items.len - start_len;
        }
        list.items.len += n;
        bw.buffer = list.unusedCapacitySlice();
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
        bw.buffer = list.unusedCapacitySlice();
        return list.items.len - start_len;
    }
    for (trailers) |bytes| list.appendSliceAssumeCapacity(bytes);
    bw.buffer = list.unusedCapacitySlice();
    return list.items.len - start_len;
}
