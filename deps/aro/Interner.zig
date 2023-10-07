const Interner = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Value = @import("Value.zig");

map: std.ArrayHashMapUnmanaged(Key, void, KeyContext, false) = .{},

const KeyContext = struct {
    pub fn eql(_: @This(), a: Key, b: Key, _: usize) bool {
        return b.eql(a);
    }

    pub fn hash(_: @This(), a: Key) u32 {
        return a.hash();
    }
};

pub const Key = union(enum) {
    int: u16,
    float: u16,
    ptr,
    noreturn,
    void,
    func,
    array: struct {
        len: u64,
        child: Ref,
    },
    vector: struct {
        len: u32,
        child: Ref,
    },
    value: Value,
    record: struct {
        /// Pointer to user data, value used for hash and equality check.
        user_ptr: *anyopaque,
        /// TODO make smaller if Value is made smaller
        elements: []const Ref,
    },

    pub fn hash(key: Key) u32 {
        var hasher = std.hash.Wyhash.init(0);
        switch (key) {
            .value => |val| {
                std.hash.autoHash(&hasher, val.tag);
                switch (val.tag) {
                    .unavailable => unreachable,
                    .nullptr_t => std.hash.autoHash(&hasher, @as(u64, 0)),
                    .int => std.hash.autoHash(&hasher, val.data.int),
                    .float => std.hash.autoHash(&hasher, @as(u64, @bitCast(val.data.float))),
                    .bytes => std.hash.autoHashStrat(&hasher, val.data.bytes, .Shallow),
                }
            },
            .record => |info| {
                std.hash.autoHash(&hasher, @intFromPtr(info.user_ptr));
            },
            inline else => |info| {
                std.hash.autoHash(&hasher, info);
            },
        }
        return @truncate(hasher.final());
    }

    pub fn eql(a: Key, b: Key) bool {
        const KeyTag = std.meta.Tag(Key);
        const a_tag: KeyTag = a;
        const b_tag: KeyTag = b;
        if (a_tag != b_tag) return false;
        switch (a) {
            .value => |a_info| {
                const b_info = b.value;
                if (a_info.tag != b_info.tag) return false;
                switch (a_info.tag) {
                    .unavailable => unreachable,
                    .nullptr_t => return true,
                    .int => return a_info.data.int == b_info.data.int,
                    .float => return a_info.data.float == b_info.data.float,
                    .bytes => return a_info.data.bytes.start == b_info.data.bytes.start and a_info.data.bytes.end == b_info.data.bytes.end,
                }
            },
            .record => |a_info| {
                return a_info.user_ptr == b.record.user_ptr;
            },
            inline else => |a_info, tag| {
                const b_info = @field(b, @tagName(tag));
                return std.meta.eql(a_info, b_info);
            },
        }
    }

    fn toRef(key: Key) ?Ref {
        switch (key) {
            .int => |bits| switch (bits) {
                1 => return .i1,
                8 => return .i8,
                16 => return .i16,
                32 => return .i32,
                64 => return .i64,
                128 => return .i128,
                else => {},
            },
            .float => |bits| switch (bits) {
                16 => return .f16,
                32 => return .f32,
                64 => return .f64,
                80 => return .f80,
                128 => return .f128,
                else => unreachable,
            },
            .ptr => return .ptr,
            .func => return .func,
            .noreturn => return .noreturn,
            .void => return .void,
            else => {},
        }
        return null;
    }
};

pub const Ref = enum(u32) {
    const max = std.math.maxInt(u32);

    ptr = max - 0,
    noreturn = max - 1,
    void = max - 2,
    i1 = max - 3,
    i8 = max - 4,
    i16 = max - 5,
    i32 = max - 6,
    i64 = max - 7,
    i128 = max - 8,
    f16 = max - 9,
    f32 = max - 10,
    f64 = max - 11,
    f80 = max - 12,
    f128 = max - 13,
    func = max - 14,
    _,
};

pub fn deinit(ip: *Interner, gpa: Allocator) void {
    ip.map.deinit(gpa);
}

pub fn put(ip: *Interner, gpa: Allocator, key: Key) !Ref {
    if (key.toRef()) |some| return some;
    const gop = try ip.map.getOrPut(gpa, key);
    return @enumFromInt(gop.index);
}

pub fn has(ip: *Interner, key: Key) ?Ref {
    if (key.toRef()) |some| return some;
    if (ip.map.getIndex(key)) |index| {
        return @enumFromInt(index);
    }
    return null;
}

pub fn get(ip: Interner, ref: Ref) Key {
    switch (ref) {
        .ptr => return .ptr,
        .func => return .func,
        .noreturn => return .noreturn,
        .void => return .void,
        .i1 => return .{ .int = 1 },
        .i8 => return .{ .int = 8 },
        .i16 => return .{ .int = 16 },
        .i32 => return .{ .int = 32 },
        .i64 => return .{ .int = 64 },
        .i128 => return .{ .int = 128 },
        .f16 => return .{ .float = 16 },
        .f32 => return .{ .float = 32 },
        .f64 => return .{ .float = 64 },
        .f80 => return .{ .float = 80 },
        .f128 => return .{ .float = 128 },
        else => {},
    }
    return ip.map.keys()[@intFromEnum(ref)];
}
