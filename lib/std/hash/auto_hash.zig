const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const meta = std.meta;

/// Describes how pointer types should be hashed.
pub const HashStrategy = enum {
    /// Do not follow pointers, only hash their value.
    Shallow,

    /// Follow pointers, hash the pointee content.
    /// Only dereferences one level, ie. it is changed into .Shallow when a
    /// pointer type is encountered.
    Deep,

    /// Follow pointers, hash the pointee content.
    /// Dereferences all pointers encountered.
    /// Assumes no cycle.
    DeepRecursive,
};

/// Helper function to hash a pointer and mutate the strategy if needed.
pub fn hashPointer(hasher: anytype, key: anytype, comptime strat: HashStrategy) void {
    const info = @typeInfo(@TypeOf(key));

    switch (info.Pointer.size) {
        .One => switch (strat) {
            .Shallow => hash(hasher, @intFromPtr(key), .Shallow),
            .Deep => hash(hasher, key.*, .Shallow),
            .DeepRecursive => hash(hasher, key.*, .DeepRecursive),
        },

        .Slice => {
            switch (strat) {
                .Shallow => {
                    hashPointer(hasher, key.ptr, .Shallow);
                },
                .Deep => hashArray(hasher, key, .Shallow),
                .DeepRecursive => hashArray(hasher, key, .DeepRecursive),
            }
            hash(hasher, key.len, .Shallow);
        },

        .Many,
        .C,
        => switch (strat) {
            .Shallow => hash(hasher, @intFromPtr(key), .Shallow),
            else => @compileError(
                \\ unknown-length pointers and C pointers cannot be hashed deeply.
                \\ Consider providing your own hash function.
            ),
        },
    }
}

/// Helper function to hash a set of contiguous objects, from an array or slice.
pub fn hashArray(hasher: anytype, key: anytype, comptime strat: HashStrategy) void {
    for (key) |element| {
        hash(hasher, element, strat);
    }
}

/// Provides generic hashing for any eligible type.
/// Strategy is provided to determine if pointers should be followed or not.
pub fn hash(hasher: anytype, key: anytype, comptime strat: HashStrategy) void {
    const Key = @TypeOf(key);
    const Hasher = switch (@typeInfo(@TypeOf(hasher))) {
        .Pointer => |ptr| ptr.child,
        else => @TypeOf(hasher),
    };

    if (strat == .Shallow and comptime meta.trait.hasUniqueRepresentation(Key)) {
        @call(.always_inline, Hasher.update, .{ hasher, mem.asBytes(&key) });
        return;
    }

    switch (@typeInfo(Key)) {
        .NoReturn,
        .Opaque,
        .Undefined,
        .Null,
        .ComptimeFloat,
        .ComptimeInt,
        .Type,
        .EnumLiteral,
        .Frame,
        .Float,
        => @compileError("unable to hash type " ++ @typeName(Key)),

        .Void => return,

        // Help the optimizer see that hashing an int is easy by inlining!
        // TODO Check if the situation is better after #561 is resolved.
        .Int => |int| switch (int.signedness) {
            .signed => hash(hasher, @bitCast(@Type(.{ .Int = .{
                .bits = int.bits,
                .signedness = .unsigned,
            } }), key), strat),
            .unsigned => {
                if (comptime meta.trait.hasUniqueRepresentation(Key)) {
                    @call(.always_inline, Hasher.update, .{ hasher, std.mem.asBytes(&key) });
                } else {
                    // Take only the part containing the key value, the remaining
                    // bytes are undefined and must not be hashed!
                    const byte_size = comptime std.math.divCeil(comptime_int, @bitSizeOf(Key), 8) catch unreachable;
                    @call(.always_inline, Hasher.update, .{ hasher, std.mem.asBytes(&key)[0..byte_size] });
                }
            },
        },

        .Bool => hash(hasher, @intFromBool(key), strat),
        .Enum => hash(hasher, @intFromEnum(key), strat),
        .ErrorSet => hash(hasher, @intFromError(key), strat),
        .AnyFrame, .Fn => hash(hasher, @intFromPtr(key), strat),

        .Pointer => @call(.always_inline, hashPointer, .{ hasher, key, strat }),

        .Optional => if (key) |k| hash(hasher, k, strat),

        .Array => hashArray(hasher, key, strat),

        .Vector => |info| {
            if (comptime meta.trait.hasUniqueRepresentation(Key)) {
                hasher.update(mem.asBytes(&key));
            } else {
                comptime var i = 0;
                inline while (i < info.len) : (i += 1) {
                    hash(hasher, key[i], strat);
                }
            }
        },

        .Struct => |info| {
            inline for (info.fields) |field| {
                // We reuse the hash of the previous field as the seed for the
                // next one so that they're dependant.
                hash(hasher, @field(key, field.name), strat);
            }
        },

        .Union => |info| {
            if (info.tag_type) |tag_type| {
                const tag = meta.activeTag(key);
                hash(hasher, tag, strat);
                inline for (info.fields) |field| {
                    if (@field(tag_type, field.name) == tag) {
                        if (field.type != void) {
                            hash(hasher, @field(key, field.name), strat);
                        }
                        // TODO use a labelled break when it does not crash the compiler. cf #2908
                        // break :blk;
                        return;
                    }
                }
                unreachable;
            } else @compileError("cannot hash untagged union type: " ++ @typeName(Key) ++ ", provide your own hash function");
        },

        .ErrorUnion => blk: {
            const payload = key catch |err| {
                hash(hasher, err, strat);
                break :blk;
            };
            hash(hasher, payload, strat);
        },
    }
}

fn typeContainsSlice(comptime K: type) bool {
    comptime {
        if (meta.trait.isSlice(K)) {
            return true;
        }
        if (meta.trait.is(.Struct)(K)) {
            inline for (@typeInfo(K).Struct.fields) |field| {
                if (typeContainsSlice(field.type)) {
                    return true;
                }
            }
        }
        if (meta.trait.is(.Union)(K)) {
            inline for (@typeInfo(K).Union.fields) |field| {
                if (typeContainsSlice(field.type)) {
                    return true;
                }
            }
        }
        return false;
    }
}

/// Provides generic hashing for any eligible type.
/// Only hashes `key` itself, pointers are not followed.
/// Slices as well as unions and structs containing slices are rejected to avoid
/// ambiguity on the user's intention.
pub fn autoHash(hasher: anytype, key: anytype) void {
    const Key = @TypeOf(key);
    if (comptime typeContainsSlice(Key)) {
        @compileError("std.hash.autoHash does not allow slices as well as unions and structs containing slices here (" ++ @typeName(Key) ++
            ") because the intent is unclear. Consider using std.hash.autoHashStrat or providing your own hash function instead.");
    }

    hash(hasher, key, .Shallow);
}

const testing = std.testing;
const Wyhash = std.hash.Wyhash;

fn testHash(key: anytype) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher = Wyhash.init(0);
    hash(&hasher, key, .Shallow);
    return hasher.final();
}

fn testHashShallow(key: anytype) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher = Wyhash.init(0);
    hash(&hasher, key, .Shallow);
    return hasher.final();
}

fn testHashDeep(key: anytype) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher = Wyhash.init(0);
    hash(&hasher, key, .Deep);
    return hasher.final();
}

fn testHashDeepRecursive(key: anytype) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher = Wyhash.init(0);
    hash(&hasher, key, .DeepRecursive);
    return hasher.final();
}

test "typeContainsSlice" {
    comptime {
        try testing.expect(!typeContainsSlice(meta.Tag(std.builtin.Type)));

        try testing.expect(typeContainsSlice([]const u8));
        try testing.expect(!typeContainsSlice(u8));
        const A = struct { x: []const u8 };
        const B = struct { a: A };
        const C = struct { b: B };
        const D = struct { x: u8 };
        try testing.expect(typeContainsSlice(A));
        try testing.expect(typeContainsSlice(B));
        try testing.expect(typeContainsSlice(C));
        try testing.expect(!typeContainsSlice(D));
    }
}

test "hash pointer" {
    const array = [_]u32{ 123, 123, 123 };
    const a = &array[0];
    const b = &array[1];
    const c = &array[2];
    const d = a;

    try testing.expect(testHashShallow(a) == testHashShallow(d));
    try testing.expect(testHashShallow(a) != testHashShallow(c));
    try testing.expect(testHashShallow(a) != testHashShallow(b));

    try testing.expect(testHashDeep(a) == testHashDeep(a));
    try testing.expect(testHashDeep(a) == testHashDeep(c));
    try testing.expect(testHashDeep(a) == testHashDeep(b));

    try testing.expect(testHashDeepRecursive(a) == testHashDeepRecursive(a));
    try testing.expect(testHashDeepRecursive(a) == testHashDeepRecursive(c));
    try testing.expect(testHashDeepRecursive(a) == testHashDeepRecursive(b));
}

test "hash slice shallow" {
    // Allocate one array dynamically so that we're assured it is not merged
    // with the other by the optimization passes.
    const array1 = try std.testing.allocator.create([6]u32);
    defer std.testing.allocator.destroy(array1);
    array1.* = [_]u32{ 1, 2, 3, 4, 5, 6 };
    const array2 = [_]u32{ 1, 2, 3, 4, 5, 6 };
    // TODO audit deep/shallow - maybe it has the wrong behavior with respect to array pointers and slices
    var runtime_zero: usize = 0;
    const a = array1[runtime_zero..];
    const b = array2[runtime_zero..];
    const c = array1[runtime_zero..3];
    try testing.expect(testHashShallow(a) == testHashShallow(a));
    try testing.expect(testHashShallow(a) != testHashShallow(array1));
    try testing.expect(testHashShallow(a) != testHashShallow(b));
    try testing.expect(testHashShallow(a) != testHashShallow(c));
}

test "hash slice deep" {
    // Allocate one array dynamically so that we're assured it is not merged
    // with the other by the optimization passes.
    const array1 = try std.testing.allocator.create([6]u32);
    defer std.testing.allocator.destroy(array1);
    array1.* = [_]u32{ 1, 2, 3, 4, 5, 6 };
    const array2 = [_]u32{ 1, 2, 3, 4, 5, 6 };
    const a = array1[0..];
    const b = array2[0..];
    const c = array1[0..3];
    try testing.expect(testHashDeep(a) == testHashDeep(a));
    try testing.expect(testHashDeep(a) == testHashDeep(array1));
    try testing.expect(testHashDeep(a) == testHashDeep(b));
    try testing.expect(testHashDeep(a) != testHashDeep(c));
}

test "hash struct deep" {
    const Foo = struct {
        a: u32,
        b: u16,
        c: *bool,

        const Self = @This();

        pub fn init(allocator: mem.Allocator, a_: u32, b_: u16, c_: bool) !Self {
            const ptr = try allocator.create(bool);
            ptr.* = c_;
            return Self{ .a = a_, .b = b_, .c = ptr };
        }
    };

    const allocator = std.testing.allocator;
    const foo = try Foo.init(allocator, 123, 10, true);
    const bar = try Foo.init(allocator, 123, 10, true);
    const baz = try Foo.init(allocator, 123, 10, false);
    defer allocator.destroy(foo.c);
    defer allocator.destroy(bar.c);
    defer allocator.destroy(baz.c);

    try testing.expect(testHashDeep(foo) == testHashDeep(bar));
    try testing.expect(testHashDeep(foo) != testHashDeep(baz));
    try testing.expect(testHashDeep(bar) != testHashDeep(baz));

    var hasher = Wyhash.init(0);
    const h = testHashDeep(foo);
    autoHash(&hasher, foo.a);
    autoHash(&hasher, foo.b);
    autoHash(&hasher, foo.c.*);
    try testing.expectEqual(h, hasher.final());

    const h2 = testHashDeepRecursive(&foo);
    try testing.expect(h2 != testHashDeep(&foo));
    try testing.expect(h2 == testHashDeep(foo));
}

test "testHash optional" {
    const a: ?u32 = 123;
    const b: ?u32 = null;
    try testing.expectEqual(testHash(a), testHash(@as(u32, 123)));
    try testing.expect(testHash(a) != testHash(b));
    try testing.expectEqual(testHash(b), 0x409638ee2bde459); // wyhash empty input hash
}

test "testHash array" {
    const a = [_]u32{ 1, 2, 3 };
    const h = testHash(a);
    var hasher = Wyhash.init(0);
    autoHash(&hasher, @as(u32, 1));
    autoHash(&hasher, @as(u32, 2));
    autoHash(&hasher, @as(u32, 3));
    try testing.expectEqual(h, hasher.final());
}

test "testHash multi-dimensional array" {
    const a = [_][]const u32{ &.{ 1, 2, 3 }, &.{ 4, 5 } };
    const b = [_][]const u32{ &.{ 1, 2 }, &.{ 3, 4, 5 } };
    try testing.expect(testHash(a) != testHash(b));
}

test "testHash struct" {
    const Foo = struct {
        a: u32 = 1,
        b: u32 = 2,
        c: u32 = 3,
    };
    const f = Foo{};
    const h = testHash(f);
    var hasher = Wyhash.init(0);
    autoHash(&hasher, @as(u32, 1));
    autoHash(&hasher, @as(u32, 2));
    autoHash(&hasher, @as(u32, 3));
    try testing.expectEqual(h, hasher.final());
}

test "testHash union" {
    const Foo = union(enum) {
        A: u32,
        B: bool,
        C: u32,
        D: void,
    };

    const a = Foo{ .A = 18 };
    var b = Foo{ .B = true };
    const c = Foo{ .C = 18 };
    const d: Foo = .D;
    try testing.expect(testHash(a) == testHash(a));
    try testing.expect(testHash(a) != testHash(b));
    try testing.expect(testHash(a) != testHash(c));
    try testing.expect(testHash(a) != testHash(d));

    b = Foo{ .A = 18 };
    try testing.expect(testHash(a) == testHash(b));

    b = .D;
    try testing.expect(testHash(d) == testHash(b));
}

test "testHash vector" {
    const a: @Vector(4, u32) = [_]u32{ 1, 2, 3, 4 };
    const b: @Vector(4, u32) = [_]u32{ 1, 2, 3, 5 };
    try testing.expect(testHash(a) == testHash(a));
    try testing.expect(testHash(a) != testHash(b));

    const c: @Vector(4, u31) = [_]u31{ 1, 2, 3, 4 };
    const d: @Vector(4, u31) = [_]u31{ 1, 2, 3, 5 };
    try testing.expect(testHash(c) == testHash(c));
    try testing.expect(testHash(c) != testHash(d));
}

test "testHash error union" {
    const Errors = error{Test};
    const Foo = struct {
        a: u32 = 1,
        b: u32 = 2,
        c: u32 = 3,
    };
    const f = Foo{};
    const g: Errors!Foo = Errors.Test;
    try testing.expect(testHash(f) != testHash(g));
    try testing.expect(testHash(f) == testHash(Foo{}));
    try testing.expect(testHash(g) == testHash(Errors.Test));
}
