// Miscellaneous utilities

const std = @import("std");

/// Returns error union payload or void if error set
fn StripError(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .error_union => |eu| eu.payload,
        .error_set => void,
        else => @compileError("no error to strip"),
    };
}

/// Checks that the value is not error. If it is error, it logs the args and
/// terminates
pub fn check(src: std.builtin.SourceLocation, v: anytype, args: anytype) StripError(@TypeOf(v)) {
    return v catch |e| {
        var buffer: [4096]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        var cw = std.io.countingWriter(fbs.writer());
        const w = cw.writer();
        if (@typeInfo(@TypeOf(args)).@"struct".fields.len != 0) {
            w.writeAll(" (") catch {};
            inline for (@typeInfo(@TypeOf(args)).@"struct".fields, 0..) |field, i| {
                const Field = @TypeOf(@field(args, field.name));
                if (i != 0) {
                    w.writeAll(", ") catch {};
                }
                if (Field == []const u8 or Field == []u8) {
                    w.print("{s}='{s}'", .{ field.name, @field(args, field.name) }) catch {};
                } else {
                    w.print("{s}={any}", .{ field.name, @field(args, field.name) }) catch {};
                }
            }
            w.writeAll(")") catch {};
        }
        std.process.fatal("{s}:{}: {s}{s}", .{ src.file, src.line, @errorName(e), buffer[0..cw.bytes_written] });
    };
}

/// Type for passing slices across extern functions where we can't use zig
/// types
pub const Slice = extern struct {
    ptr: [*]const u8,
    len: usize,

    pub fn toZig(s: Slice) []const u8 {
        return s.ptr[0..s.len];
    }

    pub fn fromZig(s: []const u8) Slice {
        return .{
            .ptr = s.ptr,
            .len = s.len,
        };
    }
};

pub fn createFileBail(dir: std.fs.Dir, sub_path: []const u8, flags: std.fs.File.CreateFlags) std.fs.File {
    return dir.createFile(sub_path, flags) catch |err| switch (err) {
        error.FileNotFound => {
            const dir_name = std.fs.path.dirname(sub_path).?;
            check(@src(), dir.makePath(dir_name), .{ .dir_name = dir_name });
            return check(@src(), dir.createFile(sub_path, flags), .{ .sub_path = sub_path, .flags = flags });
        },
        else => |e| std.process.fatal("create file '{s}' failed: {}", .{ sub_path, e }),
    };
}

/// Sorts array of features
pub fn sort(a: []u32) void {
    std.mem.sort(u32, a, void{}, std.sort.asc(u32));
}

/// Deduplicates array of sorted features
pub fn uniq(a: []u32) []u32 {
    var write: usize = 0;

    if (a.len == 0) return a;

    var last: u32 = a[0];
    a[write] = last;
    write += 1;

    for (a[1..]) |v| {
        if (v != last) {
            a[write] = v;
            write += 1;
            last = v;
        }
    }

    return a[0..write];
}

test uniq {
    var data: [9]u32 = (&[_]u32{ 0, 0, 1, 2, 2, 2, 3, 4, 4 }).*;
    const cropped = uniq(&data);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 1, 2, 3, 4 }, cropped);
}

pub const CmpResult = struct { only_a: u32, only_b: u32, both: u32 };

/// Compares two sorted lists of features
pub fn cmp(a: []const u32, b: []const u32) CmpResult {
    var ai: u32 = 0;
    var bi: u32 = 0;

    var only_a: u32 = 0;
    var only_b: u32 = 0;
    var both: u32 = 0;

    while (true) {
        if (ai == a.len) {
            only_b += @intCast(b[bi..].len);
            break;
        } else if (bi == b.len) {
            only_a += @intCast(a[ai..].len);
            break;
        }

        const i = a[ai];
        const j = b[bi];

        if (i < j) {
            only_a += 1;
            ai += 1;
        } else if (i > j) {
            only_b += 1;
            bi += 1;
        } else {
            both += 1;
            ai += 1;
            bi += 1;
        }
    }

    return .{
        .only_a = only_a,
        .only_b = only_b,
        .both = both,
    };
}

test cmp {
    const e = std.testing.expectEqual;
    const R = CmpResult;
    try e(R{ .only_a = 0, .only_b = 0, .both = 0 }, cmp(&.{}, &.{}));
    try e(R{ .only_a = 1, .only_b = 0, .both = 0 }, cmp(&.{1}, &.{}));
    try e(R{ .only_a = 0, .only_b = 1, .both = 0 }, cmp(&.{}, &.{1}));
    try e(R{ .only_a = 0, .only_b = 0, .both = 1 }, cmp(&.{1}, &.{1}));
    try e(R{ .only_a = 1, .only_b = 1, .both = 0 }, cmp(&.{1}, &.{2}));
    try e(R{ .only_a = 1, .only_b = 0, .both = 1 }, cmp(&.{ 1, 2 }, &.{1}));
    try e(R{ .only_a = 0, .only_b = 1, .both = 1 }, cmp(&.{1}, &.{ 1, 2 }));
    try e(R{ .only_a = 0, .only_b = 0, .both = 2 }, cmp(&.{ 1, 2 }, &.{ 1, 2 }));
    try e(R{ .only_a = 3, .only_b = 3, .both = 0 }, cmp(&.{ 1, 2, 3 }, &.{ 4, 5, 6 }));
}

/// Merges the second sorted list of features into the first list of sorted
/// features
pub fn merge(dest: *std.ArrayList(u32), src: []const u32) !void {
    // TODO: can be in O(n) time and O(1) space
    try dest.appendSlice(src);
    sort(dest.items);
    dest.items = uniq(dest.items);
}
