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
    pub fn demote(strat: HashStrategy) ?HashStrategy {
        return switch (strat) {
            .shallow => null,
            .deep => .shallow,
            .deep_recursive => .deep_recursive,
        };
    }
};

fn validateHashTypeSimple(comptime Key: type) void {
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
        => @compileError("unable to hash type " ++ @typeName(Key)),

        .@"union" => |info| if (info.tag_type == null) {
            @compileError("cannot hash untagged union type: " ++ @typeName(Key) ++ ", provide your own hash function");
        },

        else => {},
    }
}

/// Whether the pointer `P` points to memory which can be hashed in place.
/// This means no `volatile`, no `allowzero`, and the default `addrspace`.
inline fn pointerAttributesHashable(comptime P: type) bool {
    const info = @typeInfo(P).pointer;
    const default_addrspace = @typeInfo([]const u8).pointer.address_space;
    return !info.is_allowzero and
        !info.is_volatile and
        info.address_space == default_addrspace;
}

/// Whether `Key` can be hashed by just hashing the bytes of the value
inline fn canHashRawBytes(comptime Key: type, comptime strat: HashStrategy) bool {
    if (strat != .shallow and typeContains(Key, .pointer)) {
        // In this case, we are required
        // to dereference a pointer.
        return false;
    } else {
        // Don't include sentinels when hashing by bytes
        return std.meta.hasUniqueRepresentation(Key) and !typeContains(Key, .sentinel);
    }
}

/// Helper function to hash a value at pointer without mutating the strategy.
fn hashAtPointer(hasher: anytype, key: anytype, comptime strat: HashStrategy) void {
    const Key = @TypeOf(key);
    const info = @typeInfo(Key).pointer;

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
        // hashArray already contains logic
        // for optimally hashing spans
        hashArray(hasher, key, strat);
    } else {
        if (canHashRawBytes(info.child, strat)) {
            const bytes: []const u8 = @ptrCast(key);
            hasher.update(bytes);
        } else {
            autoHashStrat(hasher, key.*, strat);
        }
    }
}

/// Helper function to hash a set of contiguous objects, from an array or slice.
fn hashArray(hasher: anytype, key: anytype, comptime strat: HashStrategy) void {
    // Remove the sentinel
    const key_stripped = key[0..key.len];
    const KeyStripped = @TypeOf(key_stripped);
    const info = @typeInfo(KeyStripped).pointer;

    const NestedScalar = switch (@typeInfo(info.child)) {
        .array => |arr| if (arr.sentinel_ptr == null)
            arr.child
        else
            info.child,
        else => info.child,
    };

    validateHashTypeSimple(NestedScalar);

    switch (@typeInfo(NestedScalar)) {
        .array => |arr| if (arr.sentinel_ptr == null) {
            // Flatten arrays of arrays
            comptime var new_info = info;
            new_info.child = switch (info.size) {
                .slice => arr.child,
                .one => [key.len * arr.len]arr.child,
                else => unreachable,
            };
            const RealView = @Type(.{ .pointer = new_info });
            const real_arr: RealView = @ptrCast(key_stripped);
            return hashArray(hasher, real_arr, strat);
        },
        else => {},
    }

    if (comptime pointerAttributesHashable(KeyStripped)) {
        if (comptime canHashRawBytes(NestedScalar, strat)) {
            const bytes: []const u8 = @ptrCast(key_stripped);
            return hasher.update(bytes);
        }
    }

    for (key) |item| {
        autoHashStrat(hasher, item, strat);
    }
}

/// Provides generic hashing for any eligible type.
/// Strategy is provided to determine if pointers should be followed or not.
pub fn autoHashStrat(hasher: anytype, key: anytype, comptime strat: HashStrategy) void {
    const Key = @TypeOf(key);
    validateHashTypeSimple(Key);

    if (canHashRawBytes(Key, strat)) {
        // hashAtPointer has logic to convert this into
        // as single call to hasher.update
        return hashAtPointer(hasher, &key, .shallow);
    } else if (strat != .shallow and !typeContains(Key, .pointer)) {
        // Prevent the explosion of generic instantiations
        // by converting to a shallow strategy when possible
        return autoHashStrat(hasher, key, .shallow);
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
        => comptime unreachable,

        .array => return hashArray(hasher, key, strat),

        .pointer => if (comptime strat.demote()) |inner| {
            return hashAtPointer(hasher, key, inner);
        } else {
            comptime assert(strat == .shallow);
            return switch (@typeInfo(@TypeOf(key)).pointer.size) {
                .one, .many, .c => autoHashStrat(hasher, @intFromPtr(key), .shallow),
                .slice => autoHashStrat(hasher, [2]usize{
                    @intFromPtr(key.ptr),
                    key.len,
                }, .shallow),
            };
        },

        .void => return,

        // Help the optimizer see that hashing an int is easy by inlining!
        // TODO Check if the situation is better after #561 is resolved.
        .int => |int| {
            const bytesize = std.math.divCeil(comptime_int, int.bits, 8) catch unreachable;
            const ByteAligned = std.meta.Int(int.signedness, 8 * bytesize);
            const byte_aligned: ByteAligned = key;
            const bytes: [bytesize]u8 = @bitCast(byte_aligned);
            return hasher.update(&bytes);
        },

        .float => |float| {
            const AsInt = std.meta.Int(.unsigned, float.bits);
            const as_int: AsInt = @bitCast(key);
            return autoHashStrat(hasher, as_int, strat);
        },

        .bool => return autoHashStrat(hasher, @intFromBool(key), .shallow),
        .@"enum" => return autoHashStrat(hasher, @intFromEnum(key), .shallow),
        .@"anyframe" => return autoHashStrat(hasher, @intFromPtr(key), .shallow),
        .@"fn" => return autoHashStrat(hasher, @intFromPtr(&key), .shallow),

        .error_set => return autoHashStrat(hasher, @intFromError(key), strat),
        .optional => if (key) |k| return autoHashStrat(hasher, k, strat),

        .vector => |info| {
            comptime var i = 0;
            inline while (i < info.len) : (i += 1) {
                autoHashStrat(hasher, key[i], strat);
            }
        },

        .@"struct" => |info| {
            inline for (info.fields) |field| {
                // We reuse the hash of the previous field as the seed for the
                // next one so that they're dependant.
                autoHashStrat(hasher, @field(key, field.name), strat);
            }
        },

        .@"union" => |info| {
            autoHashStrat(hasher, @as(info.tag_type.?, key), strat);
            switch (key) {
                inline else => |payload| autoHashStrat(hasher, payload, strat),
            }
        },

        .error_union => {
            if (key) |payload| {
                return autoHashStrat(hasher, payload, strat);
            } else |err| {
                return autoHashStrat(hasher, err, strat);
            }
        },
    }
}

inline fn typeContains(comptime K: type, comptime kind: enum { slice, pointer, sentinel }) bool {
    return switch (@typeInfo(K)) {
        .pointer => |info| switch (kind) {
            .sentinel => false,
            .pointer => true,
            .slice => info.size == .slice,
        },

        .@"union" => |info| inline for (info.fields) |field| {
            if (typeContains(field.type, kind)) break true;
        } else false,

        .@"struct" => |info| inline for (info.fields) |field| {
            if (typeContains(field.type, kind)) break true;
        } else false,

        .vector => |info| info.len > 0 and typeContains(info.child, kind),
        .optional => |info| typeContains(info.child, kind),
        .error_union => |info| typeContains(info.payload, kind),

        .array => |info| switch (kind) {
            .sentinel => info.sentinel_ptr == null,
            .slice, .pointer => false,
        } or (info.len > 0 and typeContains(info.child, kind)),

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
        @compileError("std.hash.autoHash does not allow slices or types containing slices here (" ++ @typeName(Key) ++
            ") because the intent is unclear. Consider using std.hash.autoHashStrat or providing your own hash function instead.");
    }

    autoHashStrat(hasher, key, .shallow);
}

const testing = std.testing;
const Wyhash = std.hash.Wyhash;

fn testHash(key: anytype) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher: Wyhash = .init(0);
    autoHashStrat(&hasher, key, .shallow);
    return hasher.final();
}

fn testHashShallow(key: anytype) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher: Wyhash = .init(0);
    autoHashStrat(&hasher, key, .shallow);
    return hasher.final();
}

fn testHashDeep(key: anytype) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher: Wyhash = .init(0);
    autoHashStrat(&hasher, key, .deep);
    return hasher.final();
}

fn testHashDeepRecursive(key: anytype) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher: Wyhash = .init(0);
    autoHashStrat(&hasher, key, .deep_recursive);
    return hasher.final();
}

test typeContains {
    try comptime testing.expect(!typeContains(std.meta.Tag(std.builtin.Type), .slice));

    try comptime testing.expect(typeContains([]const u8, .slice));
    try comptime testing.expect(!typeContains(u8, .slice));

    const A = struct { x: []const u8 };
    const B = struct { a: A };
    const C = struct { b: B };

    try comptime testing.expect(typeContains(A, .slice));
    try comptime testing.expect(typeContains(B, .slice));
    try comptime testing.expect(typeContains(C, .slice));
    try comptime testing.expect(typeContains(A, .pointer));
    try comptime testing.expect(typeContains(B, .pointer));
    try comptime testing.expect(typeContains(C, .pointer));
    try comptime testing.expect(!typeContains(A, .sentinel));
    try comptime testing.expect(!typeContains(B, .sentinel));
    try comptime testing.expect(!typeContains(C, .sentinel));

    const D = struct { x: [1][4:null]?[*]u8 };
    try comptime testing.expect(!typeContains(D, .slice));
    try comptime testing.expect(typeContains(D, .pointer));
    try comptime testing.expect(typeContains(D, .sentinel));
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
