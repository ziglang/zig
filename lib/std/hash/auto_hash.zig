const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;

/// Describes how pointer types should be hashed.
pub const HashStrategy = enum {
    /// Do not follow pointers, only hash their value.
    shallow,

    /// Follow pointers, hash the pointee content.
    /// Only dereferences one level, ie. it is changed into .Shallow when a
    /// pointer type is encountered.
    deep,

    /// Follow pointers, hash the pointee content.
    /// Dereferences all pointers encountered.
    /// Assumes no cycle.
    deep_recursive,

    /// Deprecated alias for `shallow`
    pub const Shallow: HashStrategy = .shallow;

    /// Deprecated alias for `deep`
    pub const Deep: HashStrategy = .deep;

    /// Deprecated alias for `deep_recursive`
    pub const DeepRecursive: HashStrategy = .deep_recursive;

    /// Returns the hash strategy used when hashing fields with `strat`.
    pub inline fn demote(comptime strat: HashStrategy) ?HashStrategy {
        return switch (strat) {
            .shallow => null,
            .deep => .shallow,
            .deep_recursive => .deep_recursive,
        };
    }
};

/// Helper function to hash a value at pointer without mutating the strategy.
pub fn hashAtPointer(hasher: anytype, key: anytype, comptime strat: HashStrategy) void {
    const info = @typeInfo(@TypeOf(key)).pointer;

    const is_span = switch (info.size) {
        .slice => true,
        .one => switch (@typeInfo(info.child)) {
            .array => true,
            else => false,
        },
        .many, .c => @compileError(
            \\ unknown-length pointers and C pointers cannot be hashed deeply.
            \\ Consider providing your own hash function.
        ),
    };

    if (is_span) {
        return hashArray(hasher, key, strat);
    } else {
        return hash(hasher, key.*, strat);
    }
}

/// Helper function to hash a set of contiguous objects, from an array or slice.
pub fn hashArray(hasher: anytype, key: anytype, comptime strat: HashStrategy) void {
    // Remove the sentinel
    const key_stripped = key[0..key.len];
    const KeyStripped = @TypeOf(key_stripped);
    const info = @typeInfo(KeyStripped).pointer;

    const Scalar = switch (@typeInfo(info.child)) {
        .array => |arr| if (arr.sentinel_ptr == null)
            arr.child
        else
            info.child,
        else => info.child,
    };

    switch (@typeInfo(Scalar)) {
        .array => |arr| {
            // Flatten arrays of arrays
            comptime var new_info = info;
            new_info.size, new_info.child = switch (info.size) {
                .slice => .{ .slice, Scalar },
                .one => .{ .one, [key.len * arr.len]Scalar },
                else => unreachable,
            };
            const RealView = @Type(.{ .pointer = new_info });
            const real_arr: RealView = @ptrCast(key[0..key.len]);
            return hashArray(hasher, real_arr, strat);
        },
        else => {},
    }

    const default_addrspace = @typeInfo([]const u8).pointer.address_space;
    const pointer_location_hashable = !info.is_allowzero and
        !info.is_volatile and
        info.address_space == default_addrspace;

    if (comptime pointer_location_hashable) {
        const use_shallow = comptime strat == .shallow or !typeContains(Scalar, .pointer);
        if (use_shallow) {
            if (comptime std.meta.hasUniqueRepresentation(Scalar)) {
                const Hasher = switch (@typeInfo(@TypeOf(hasher))) {
                    .pointer => |hasher_pointer| hasher_pointer.child,
                    else => @TypeOf(hasher),
                };
                const bytes: []const u8 = @ptrCast(key_stripped);
                return @call(.always_inline, Hasher.update, .{ hasher, bytes });
            }
        } else if (strat == .deep_recursive and @sizeOf(info.child) > @sizeOf(usize)) {
            for (key) |*item| {
                @call(.always_inline, hashAtPointer, .{ hasher, item, .deep_recursive });
            }
            return;
        }
    }

    for (key) |item| {
        hash(hasher, item, strat);
    }
}

/// Helper function to hash a pointer without and mutate the strategy if needed.
pub fn hashPointer(hasher: anytype, key: anytype, comptime strat: HashStrategy) void {
    if (strat.demote()) |inner| {
        hashAtPointer(hasher, key, inner);
    } else {
        switch (@typeInfo(@TypeOf(key)).pointer.size) {
            .one, .many, .c => {},
            .slice => {
                const data: [2]usize = .{
                    @intFromPtr(key.ptr),
                    key.len,
                };
                hash(hasher, data, .shallow);
            },
        }
    }
}

/// Provides generic hashing for any eligible type.
/// Strategy is provided to determine if pointers should be followed or not.
pub fn hash(hasher: anytype, key: anytype, comptime strat: HashStrategy) void {
    const Key = @TypeOf(key);
    const Hasher = switch (@typeInfo(@TypeOf(hasher))) {
        .pointer => |ptr| ptr.child,
        else => @TypeOf(hasher),
    };

    // Guard clause for types which
    // should not be hashed via a @ptrCast to u8
    switch (@typeInfo(Key)) {
        .noreturn,
        .@"opaque",
        .undefined,
        .null,
        .comptime_float,
        .comptime_int,
        .type,
        .enum_literal,
        .frame,
        .float,
        => @compileError("unable to hash type " ++ @typeName(Key)),

        .array => return hashArray(hasher, key, strat),

        .@"union" => |info| {
            if (info.tag_type == null) {
                @compileError("cannot hash untagged union type: " ++ @typeName(Key) ++ ", provide your own hash function");
            }
        },

        else => {},
    }

    if ((strat == .shallow or !typeContains(Key, .pointer)) and std.meta.hasUniqueRepresentation(Key)) {
        return @call(.always_inline, Hasher.update, .{ hasher, mem.asBytes(&key) });
    }

    switch (@typeInfo(Key)) {
        .noreturn,
        .@"opaque",
        .undefined,
        .null,
        .comptime_float,
        .comptime_int,
        .type,
        .enum_literal,
        .frame,
        .float,
        .array,
        => comptime unreachable,

        .void => return,

        // Help the optimizer see that hashing an int is easy by inlining!
        // TODO Check if the situation is better after #561 is resolved.
        .int => |int| switch (int.signedness) {
            .signed => hash(hasher, @as(@Type(.{ .int = .{
                .bits = int.bits,
                .signedness = .unsigned,
            } }), @bitCast(key)), strat),
            .unsigned => {
                // Take only the part containing the key value, the remaining
                // bytes are undefined and must not be hashed!
                const byte_size = comptime std.math.divCeil(comptime_int, @bitSizeOf(Key), 8) catch unreachable;
                @call(.always_inline, Hasher.update, .{ hasher, std.mem.asBytes(&key)[0..byte_size] });
            },
        },

        .bool => hash(hasher, @intFromBool(key), strat),
        .@"enum" => hash(hasher, @intFromEnum(key), strat),
        .error_set => hash(hasher, @intFromError(key), strat),
        .@"anyframe", .@"fn" => hash(hasher, @intFromPtr(key), strat),

        .pointer => hashPointer(hasher, key, strat),

        .optional => if (key) |k| hash(hasher, k, strat),

        .vector => |info| {
            comptime var i = 0;
            inline while (i < info.len) : (i += 1) {
                hash(hasher, key[i], strat);
            }
        },

        .@"struct" => |info| {
            inline for (info.fields) |field| {
                if (field.is_comptime) continue;
                // We reuse the hash of the previous field as the seed for the
                // next one so that they're dependant.
                hash(hasher, @field(key, field.name), strat);
            }
        },

        .@"union" => |info| {
            if (info.fields.len == 0) {
                return;
            } else switch (key) {
                inline else => |*payload, un_tag| {
                    if (info.fields.len > 1) {
                        hash(hasher, un_tag, strat);
                    }
                    hash(hasher, payload, strat);
                },
            }
        },

        .error_union => {
            if (key) |payload| {
                hash(hasher, payload, strat);
            } else |err| {
                hash(hasher, err, strat);
            }
        },
    }
}

inline fn typeContains(comptime K: type, comptime what: enum { pointer, slice }) bool {
    return switch (@typeInfo(K)) {
        .pointer => |info| switch (what) {
            .pointer => true,
            .slice => info.size == .slice,
        },

        .@"union" => |info| inline for (info.fields) |field| {
            if (typeContains(field.type, what)) {
                break true;
            }
        } else false,

        .@"struct" => |info| inline for (info.fields) |field| {
            if (field.is_comptime) continue;
            if (typeContains(field.type, what)) {
                break true;
            }
        } else false,

        .array => |info| (info.sentinel_ptr == null or info.len > 0) and typeContains(info.child, what),

        .optional => |info| typeContains(info.child, what),
        .error_union => |info| typeContains(info.payload, what),

        else => false,
    };
}

/// Provides generic hashing for any eligible type.
/// Only hashes `key` itself, pointers are not followed.
/// Slices as well as unions and structs containing slices are rejected to avoid
/// ambiguity on the user's intention.
pub fn autoHash(hasher: anytype, key: anytype) void {
    const Key = @TypeOf(key);
    if (comptime typeContains(Key, .slice)) {
        @compileError("std.hash.autoHash does not allow slices as well as unions and structs containing slices here (" ++ @typeName(Key) ++
            ") because the intent is unclear. Consider using std.hash.autoHashStrat or providing your own hash function instead.");
    }

    hash(hasher, key, .shallow);
}

const testing = std.testing;
const Wyhash = std.hash.Wyhash;

fn testHash(key: anytype) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher: Wyhash = .init(0);
    hash(&hasher, key, .shallow);
    return hasher.final();
}

fn testHashShallow(key: anytype) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher: Wyhash = .init(0);
    hash(&hasher, key, .shallow);
    return hasher.final();
}

fn testHashDeep(key: anytype) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher: Wyhash = .init(0);
    hash(&hasher, key, .Deep);
    return hasher.final();
}

fn testHashDeepRecursive(key: anytype) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher: Wyhash = .init(0);
    hash(&hasher, key, .deep_recursive);
    return hasher.final();
}

test typeContains {
    comptime {
        try testing.expect(!typeContains(std.meta.Tag(std.builtin.Type), .slice));

        try testing.expect(typeContains([]const u8, .slice));
        try testing.expect(!typeContains(u8, .pointer));
        const A = struct { x: []const u8 };
        const B = struct { a: A };
        const C = struct { b: B };
        const D = struct { x: u8 };
        try testing.expect(typeContains(A, .slice));
        try testing.expect(typeContains(B, .slice));
        try testing.expect(typeContains(C, .slice));
        try testing.expect(!typeContains(D, .pointer));
    }
}

test "hash pointer" {
    const array: [3]u32 = .{ 123, 123, 123 };
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
    array1.* = .{ 1, 2, 3, 4, 5, 6 };
    const array2: [6]u32 = .{ 1, 2, 3, 4, 5, 6 };
    // TODO audit deep/shallow - maybe it has the wrong behavior with respect to array pointers and slices
    var runtime_zero: usize = 0;
    _ = &runtime_zero;
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
    array1.* = .{ 1, 2, 3, 4, 5, 6 };
    const array2: [6]u32 = .{ 1, 2, 3, 4, 5, 6 };
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

        fn init(allocator: mem.Allocator, a_: u32, b_: u16, c_: bool) !Self {
            const ptr = try allocator.create(bool);
            ptr.* = c_;
            return Self{ .a = a_, .b = b_, .c = ptr };
        }
    };

    const allocator = std.testing.allocator;
    const foo: Foo = try .init(allocator, 123, 10, true);
    const bar: Foo = try .init(allocator, 123, 10, true);
    const baz: Foo = try .init(allocator, 123, 10, false);
    defer allocator.destroy(foo.c);
    defer allocator.destroy(bar.c);
    defer allocator.destroy(baz.c);

    try testing.expect(testHashDeep(foo) == testHashDeep(bar));
    try testing.expect(testHashDeep(foo) != testHashDeep(baz));
    try testing.expect(testHashDeep(bar) != testHashDeep(baz));

    var hasher: Wyhash = .init(0);
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
    try testing.expectEqual(0x409638ee2bde459, testHash(b)); // wyhash empty input hash
}

test "testHash array" {
    const a: [3]u32 = .{ 1, 2, 3 };
    const h = testHash(a);
    var hasher: Wyhash = .init(0);
    autoHash(&hasher, @as(u32, 1));
    autoHash(&hasher, @as(u32, 2));
    autoHash(&hasher, @as(u32, 3));
    try testing.expectEqual(hasher.final(), h);
}

test "testHash array of slices" {
    const a: [2][]const u32 = .{ &.{ 1, 2, 3 }, &.{ 4, 5 } };
    const b: [2][]const u32 = .{ &.{ 1, 2 }, &.{ 3, 4, 5 } };
    try testing.expect(testHash(a) != testHash(b));
}

test "testHash struct" {
    const Foo = struct {
        a: u32 = 1,
        b: u32 = 2,
        c: u32 = 3,
    };
    const f: Foo = .{};
    const h = testHash(f);
    var hasher: Wyhash = .init(0);
    autoHash(&hasher, @as(u32, 1));
    autoHash(&hasher, @as(u32, 2));
    autoHash(&hasher, @as(u32, 3));
    try testing.expectEqual(hasher.final(), h);
}

test "testHash union" {
    const Foo = union(enum) {
        A: u32,
        B: bool,
        C: u32,
        D: void,
    };

    const a: Foo = .{ .A = 18 };
    var b: Foo = .{ .B = true };
    const c: Foo = .{ .C = 18 };
    const d: Foo = .D;
    try testing.expect(testHash(a) == testHash(a));
    try testing.expect(testHash(a) != testHash(b));
    try testing.expect(testHash(a) != testHash(c));
    try testing.expect(testHash(a) != testHash(d));

    b = .{ .A = 18 };
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
    const f: Foo = .{};
    const g: Errors!Foo = Errors.Test;
    try testing.expect(testHash(f) != testHash(g));
    try testing.expect(testHash(f) == testHash(Foo{}));
    try testing.expect(testHash(g) == testHash(Errors.Test));
}
