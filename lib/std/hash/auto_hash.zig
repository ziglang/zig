const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Wyhash = std.hash.Wyhash;

/// Describes how pointer types should be hashed.
pub const Strategy = enum {
    /// Do not follow pointers, only hash their value.
    shallow,

    /// Follow pointers once, hash the pointee content.
    /// Only dereferences one level, ie. it is changed into `shallow` when a
    /// pointer type is encountered.
    deep,

    /// Follow pointers recursively, hash the pointee content.
    /// Dereferences all pointers encountered.
    /// Assumes no cycle.
    deep_recursive,

    /// Deprecated alias for `shallow`
    pub const Shallow: Strategy = .shallow;

    /// Deprecated alias for `deep`
    pub const Deep: Strategy = .deep;

    /// Deprecated alias for `deep_recursive`
    pub const DeepRecursive: Strategy = .deep_recursive;

    /// When hashing a pointer with `strat`,
    /// this returns the strategy used to hash
    /// the data at the pointer. If this returns
    /// `null`, then the pointer itself should
    /// be hashed.
    fn deref(strat: Strategy) ?Strategy {
        return switch (strat) {
            .shallow => null,
            .deep => .shallow,
            .deep_recursive => .deep_recursive,
        };
    }

    /// Returns a `Strategy` that is equivalent to `strat` for
    /// use in hashing values of type `T`. Used for preventing
    /// the explosion of generic instantiation.
    fn deduplicate(comptime strat: Strategy, comptime T: type) ?Strategy {
        if (strat != .shallow and !typeContains(T, .pointer)) {
            return .shallow;
        }
        return null;
    }
};

/// Whether the pointer type `P` points to directly hashable memory.
/// This means non-volatile, non-nullable, and default address space.
fn isMemoryHashable(comptime Pointer: type) bool {
    // Instead of checking the is_volatile, address_space, and is_allowzero
    // fields directly, we modify the fields we don't care about
    // and check if reifying the info results in []const u8.
    // This allows us to handle pointers to packed struct fields,
    // which cannot be observed from @typeInfo.
    comptime var info = @typeInfo(Pointer).pointer;
    if (info.size == .c) {
        // C pointers are nullable
        return false;
    }
    info.child = u8;
    info.size = .slice;
    info.is_const = true;
    info.alignment = 1;
    info.sentinel_ptr = null;
    return @Type(.{ .pointer = info }) == []const u8;
}

/// Whether `T` can be safely hashed by hashing its raw bytes
fn hashByBytes(comptime T: type, strat: Strategy) bool {
    if (strat == .shallow or !typeContains(T, .pointer)) {
        // Don't include sentinels in the hashes
        return std.meta.hasUniqueRepresentation(T) and !typeContains(T, .sentinel);
    } else {
        return false;
    }
}

/// Whether an effort should be made to avoid copying values
/// of type `T`. When this returns true,
fn preferInPlaceHash(comptime T: type) bool {
    return @sizeOf(T) > @sizeOf(usize);
}

/// Helper function to hash a pointer and mutate the strategy if needed.
fn hashInPlace(hasher: anytype, key: anytype, comptime strat: Strategy) void {
    const KeyPtr = @TypeOf(key);
    const info = @typeInfo(KeyPtr).pointer;

    const is_span = switch (info.size) {
        .one => @typeInfo(info.child) == .array,
        .slice => true,
        .many, .c => if (strat != .shallow) @compileError(
            \\ unknown-length pointers and C pointers cannot be hashed deeply.
            \\ Consider providing your own hash function.
        ),
    };

    if (comptime is_span) {
        // hashArray already has logic to hash slices and
        // array pointers optimally
        return hashArray(hasher, key, strat);
    } else if (comptime strat.deduplicate(info.child)) |new_strat| {
        // Here we prevent the explosion of generic instantiation
        // for all of the following logic. We do this after the
        // is_span check because hashArray also does this.
        return hashInPlace(hasher, key, new_strat);
    } else if (comptime isMemoryHashable(KeyPtr) and hashByBytes(info.child, strat)) {
        // If the memory is non-nullable, non-volatile,
        // and byte-aligned, then we can try optimizing
        // to hash the key in place. This is also attempted
        // in autoStrat, but by doing it here, we can avoid
        // a redundant copy of the data
        const bytes: []const u8 = @ptrCast(key);
        return hasher.update(bytes);
    } else {
        // In the general case, just dereference the key
        // and pass it on to autoStrat
        return autoStrat(hasher, key.*, strat);
    }
}

/// Helper function to hash a set of contiguous objects, from an array or slice.
fn hashArray(hasher: anytype, key: anytype, comptime strat: Strategy) void {
    // Exclude the sentinel in all of the following code
    const no_sent = key[0..key.len];
    const NoSent = @TypeOf(no_sent);

    const info = @typeInfo(NoSent).pointer;

    if (comptime strat.deduplicate(info.child)) |new_strat| {
        // Prevent the explosion of generic instantiation
        // by demoting strat to shallow when there are no
        // pointers within the key
        return hashArray(hasher, no_sent, new_strat);
    }

    const Child = std.meta.Elem(NoSent);

    switch (@typeInfo(Child)) {
        .array => |arr| if (arr.sentinel_ptr != null) {
            // Attempt to flatten arrays of arrays when possible
            comptime var flat_info = info;
            flat_info.child = switch (info.size) {
                .slice => arr.child,
                else => [arr.len * no_sent.len]arr.child,
            };
            const Flat = @Type(.{ .pointer = flat_info });
            const flat: Flat = @ptrCast(no_sent);
            return hashArray(hasher, flat, strat);
        },
        else => {},
    }

    // If the memory is non-nullable, non-volatile,
    // and byte-aligned, then we can try optimizing
    // to hash the key in place
    if (comptime isMemoryHashable(NoSent)) {
        if (comptime preferInPlaceHash(Child)) {
            // Otherwise, if the data is sufficiently large,
            // we attempt to hash as much as possible in place
            // by passing the elements to hashAtPointer
            for (no_sent) |*element| {
                hashInPlace(hasher, element, strat);
            }
            return;
        }
    }

    // In the general case, we use a regular, by value for loop
    for (no_sent) |element| {
        autoStrat(hasher, element, strat);
    }
    return;
}

fn validateTypeInfo(comptime T: type) void {
    switch (@typeInfo(T)) {
        .noreturn,
        .@"opaque",
        .undefined,
        .null,
        .comptime_float,
        .comptime_int,
        .type,
        .enum_literal,
        .frame,
        => @compileError("unable to hash type " ++ @typeName(T)),

        .@"union" => |info| if (info.tag_type == null)
            @compileError("cannot hash untagged union type: " ++ @typeName(T) ++ ", provide your own hash function"),

        else => {},
    }
}

/// Provides generic hashing for any eligible type.
/// Strategy is provided to determine if pointers should be followed or not.
pub fn autoStrat(hasher: anytype, key: anytype, comptime strat: Strategy) void {
    const Key = @TypeOf(key);
    validateTypeInfo(Key);

    if (comptime strat.deduplicate(Key)) |new_strat| {
        // Prevent the explosion of generic instantiation
        // by demoting strat to shallow when there are no
        // pointers within the key
        return autoStrat(hasher, key, new_strat);
    }

    if (comptime hashByBytes(Key, strat)) {
        // If it is safe to do so, we skip all of the
        // field-by-field hashing logic and just directly
        // hash the bytes of the value. It's generally better
        // for this to happen inside hashInPlace so we aren't
        // making unnecessary copies of the key, but it should
        // be checked here too
        const bytes: []const u8 = @ptrCast(&key);
        return hasher.update(bytes);
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

        .void => return,

        .int => |int| {
            const byte_size = comptime std.math.divCeil(comptime_int, @bitSizeOf(Key), 8) catch unreachable;
            const ByteAligned = std.meta.Int(int.signedness, byte_size * 8);
            const byte_aligned: ByteAligned = key;
            const bytes: [byte_size]u8 = @bitCast(byte_aligned);
            return hasher.update(&bytes);
        },

        .float => |float| {
            const AsInt = std.meta.Int(.unsigned, float.bits);
            const as_int: AsInt = @bitCast(key);
            return autoStrat(hasher, as_int, .shallow);
        },

        .bool => return autoStrat(hasher, @intFromBool(key), strat),
        .@"enum" => return autoStrat(hasher, @intFromEnum(key), strat),
        .error_set => return autoStrat(hasher, @intFromError(key), strat),
        .@"anyframe" => return autoStrat(hasher, @intFromPtr(key), strat),
        .@"fn" => return autoStrat(hasher, @intFromPtr(&key), strat),

        .array => return hashArray(hasher, key[0..key.len], strat),

        .pointer => |info| {
            if (comptime strat.deref()) |deref_strat| {
                return hashInPlace(hasher, key, deref_strat);
            } else {
                switch (info.size) {
                    .one, .many, .c => return autoStrat(hasher, @intFromPtr(key), .shallow),
                    .slice => {
                        const data: [2]usize = .{
                            @intFromPtr(key.ptr),
                            key.len,
                        };
                        return autoStrat(hasher, data, .shallow);
                    },
                }
            }
        },

        .optional => |info| {
            if (comptime preferInPlaceHash(info.child)) {
                if (key) |*k| {
                    return hashInPlace(hasher, k, strat);
                }
            } else {
                if (key) |k| {
                    return autoStrat(hasher, k, strat);
                }
            }
            return;
        },

        .vector => |info| {
            inline for (0..info.len) |i| {
                autoStrat(hasher, key[i], strat);
            }
            return;
        },

        .@"struct" => |info| {
            inline for (info.fields) |field| {
                if (field.is_comptime) continue;

                if (comptime info.layout != .@"packed" and preferInPlaceHash(field.type)) {
                    hashInPlace(hasher, &@field(key, field.name), strat);
                } else {
                    autoStrat(hasher, @field(key, field.name), strat);
                }
            }
            return;
        },

        .@"union" => |info| {
            const tag: info.tag_type.? = key;
            autoStrat(hasher, tag, .shallow);
            switch (key) {
                inline else => |*payload| {
                    const Field = @TypeOf(payload.*);
                    if (comptime preferInPlaceHash(Field)) {
                        return hashInPlace(hasher, payload, strat);
                    } else {
                        return autoStrat(hasher, payload.*, strat);
                    }
                },
            }
        },

        .error_union => |info| {
            if (key) |*payload| {
                if (comptime preferInPlaceHash(info.payload)) {
                    return hashInPlace(hasher, payload, strat);
                } else {
                    return autoStrat(hasher, payload.*, strat);
                }
            } else |err| {
                return autoStrat(hasher, err, strat);
            }
        },
    }
}

/// Provides generic hashing for any eligible type.
/// Only hashes `key` itself, pointers are not followed.
/// Slices as well as unions and structs containing slices are rejected to avoid
/// ambiguity on the user's intention.
pub fn auto(hasher: anytype, key: anytype) void {
    const Key = @TypeOf(key);
    if (comptime typeContains(Key, .slice)) {
        @compileError("std.hash.auto does not allow slices as well as unions and structs containing slices here (" ++ @typeName(Key) ++
            ") because the intent is unclear. Consider using std.hash.autoStrat or providing your own hash function instead.");
    }

    autoStrat(hasher, key, .shallow);
}

inline fn typeContains(comptime K: type, comptime what: enum { slice, pointer, sentinel }) bool {
    return switch (@typeInfo(K)) {
        .pointer => |info| switch (what) {
            .pointer => true,
            .slice => info.size == .slice,
            .sentinel => false,
        },

        .@"struct" => |info| inline for (info.fields) |field| {
            if (!field.is_comptime) {
                if (typeContains(field.type, what)) break true;
            }
        } else false,

        .@"union" => |info| inline for (info.fields) |field| {
            if (typeContains(field.type, what)) break true;
        } else false,

        .array => |info| switch (what) {
            .sentinel => info.sentinel_ptr != null,
            .pointer, .slice => false,
        } or (info.len > 0 and typeContains(info.child, what)),

        .vector => |info| info.len > 0 and typeContains(info.child, what),

        .optional => |info| typeContains(info.child, what),
        .error_union => |info| typeContains(info.payload, what),

        else => false,
    };
}

test typeContains {
    try comptime expect(!typeContains(std.builtin.TypeId, .slice));
    try comptime expect(typeContains([]const u8, .slice));
    try comptime expect(!typeContains(u8, .slice));

    const A = struct { x: []const u8 };
    const B = struct { a: A };
    const C = struct { b: B };
    const D = struct { x: u8, y: [40:0]u16 };

    try comptime expect(typeContains(A, .slice));
    try comptime expect(typeContains(B, .slice));
    try comptime expect(typeContains(C, .slice));
    try comptime expect(!typeContains(D, .slice));
    try comptime expect(typeContains(D, .sentinel));
}

fn testHash(key: anytype) u64 {
    // Any hash could be used here, for testing autoStrat.
    var hasher: Wyhash = .init(0);
    auto(&hasher, key);
    return hasher.final();
}

fn testHashShallow(key: anytype) u64 {
    // Any hash could be used here, for testing autoStrat.
    var hasher: Wyhash = .init(0);
    autoStrat(&hasher, key, .shallow);
    return hasher.final();
}

fn testHashDeep(key: anytype) u64 {
    // Any hash could be used here, for testing autoStrat.
    var hasher: Wyhash = .init(0);
    autoStrat(&hasher, key, .deep);
    return hasher.final();
}

fn testHashDeepRecursive(key: anytype) u64 {
    // Any hash could be used here, for testing auto.
    var hasher: Wyhash = .init(0);
    autoStrat(&hasher, key, .deep_recursive);
    return hasher.final();
}

test "hash pointer" {
    const array: [3]u32 = .{ 123, 123, 123 };
    const a = &array[0];
    const b = &array[1];
    const c = &array[2];
    const d = a;

    try expectEqual(testHashShallow(a), testHashShallow(d));
    try expect(testHashShallow(a) != testHashShallow(c));
    try expect(testHashShallow(a) != testHashShallow(b));

    try expectEqual(testHashDeep(a), testHashDeep(a));
    try expectEqual(testHashDeep(a), testHashDeep(c));
    try expectEqual(testHashDeep(a), testHashDeep(b));

    try expectEqual(testHashDeepRecursive(a), testHashDeepRecursive(a));
    try expectEqual(testHashDeepRecursive(a), testHashDeepRecursive(c));
    try expectEqual(testHashDeepRecursive(a), testHashDeepRecursive(b));
}

test "hash slice shallow" {
    var array1: [6]u32 = undefined;
    std.mem.doNotOptimizeAway(array1);
    array1 = .{ 1, 2, 3, 4, 5, 6 };

    const array2: [6]u32 = .{ 1, 2, 3, 4, 5, 6 };

    var runtime_zero: usize = 0;
    std.mem.doNotOptimizeAway(&runtime_zero);

    const a = array1[runtime_zero..];
    const b = array2[runtime_zero..];
    const c = array1[runtime_zero..3];

    try expectEqual(testHashShallow(a), testHashShallow(a));
    try expect(testHashShallow(a) != testHashShallow(array1));
    try expect(testHashShallow(a) != testHashShallow(b));
    try expect(testHashShallow(a) != testHashShallow(c));
}

test "hash slice deep" {
    var array1: [6]u32 = undefined;
    std.mem.doNotOptimizeAway(array1);
    array1 = .{ 1, 2, 3, 4, 5, 6 };

    const array2: [6]u32 = .{ 1, 2, 3, 4, 5, 6 };

    const a = array1[0..];
    const b = array2[0..];
    const c = array1[0..3];

    try expectEqual(testHashDeep(a), testHashDeep(a));
    try expectEqual(testHashDeep(a), testHashDeep(array1));
    try expectEqual(testHashDeep(a), testHashDeep(b));
    try expect(testHashDeep(a) != testHashDeep(c));
}

test "hash struct deep" {
    const Foo = struct {
        a: u32,
        b: u16,
        c: *bool,

        const Foo = @This();

        fn init(allocator: mem.Allocator, a: u32, b: u16, c: bool) mem.Allocator.Error!Foo {
            const ptr = try allocator.create(bool);
            ptr.* = c;
            return .{
                .a = a,
                .b = b,
                .c = ptr,
            };
        }

        fn deinit(self: Foo, allocator: mem.Allocator) void {
            allocator.destroy(self.c);
        }
    };

    const allocator = std.testing.allocator;

    const foo: Foo = try .init(allocator, 123, 10, true);
    defer foo.deinit(allocator);

    const bar: Foo = try .init(allocator, 123, 10, true);
    defer bar.deinit(allocator);

    const baz: Foo = try .init(allocator, 123, 10, false);
    defer baz.deinit(allocator);

    try expectEqual(testHashDeep(foo), testHashDeep(bar));
    try expect(testHashDeep(foo) != testHashDeep(baz));
    try expect(testHashDeep(bar) != testHashDeep(baz));

    var hasher: Wyhash = .init(0);
    const h = testHashDeep(foo);
    auto(&hasher, foo.a);
    auto(&hasher, foo.b);
    auto(&hasher, foo.c.*);
    try expectEqual(h, hasher.final());

    const h2 = testHashDeepRecursive(&foo);
    try expect(h2 != testHashDeep(&foo));
    try expectEqual(h2, testHashDeep(foo));
}

test "hash optional" {
    const a: ?u32 = 123;
    const b: ?u32 = null;
    try expectEqual(testHash(a), testHash(@as(u32, 123)));
    try expect(testHash(a) != testHash(b));
    try expectEqual(testHash(b), 0x409638ee2bde459); // wyhash empty input hash
}

test "hash array" {
    const a: [3]u32 = .{ 1, 2, 3 };
    const h = testHash(a);
    var hasher: Wyhash = .init(0);
    auto(&hasher, @as(u32, 1));
    auto(&hasher, @as(u32, 2));
    auto(&hasher, @as(u32, 3));
    try expectEqual(h, hasher.final());
}

test "hash array of slices" {
    const a: [2][]const u32 = .{ &.{ 1, 2, 3 }, &.{ 4, 5 } };
    const b: [2][]const u32 = .{ &.{ 1, 2 }, &.{ 3, 4, 5 } };
    try expectEqual(testHashDeep(a), testHashDeep(b));
    try expect(testHashShallow(a) != testHashShallow(b));
}

test "hash struct" {
    const Foo = struct {
        a: u32,
        b: u32,
        c: u32,
    };

    const f: Foo = .{
        .a = 1,
        .b = 2,
        .c = 3,
    };

    const h = testHash(f);
    var hasher: Wyhash = .init(0);
    auto(&hasher, @as(u32, 1));
    auto(&hasher, @as(u32, 2));
    auto(&hasher, @as(u32, 3));
    try expectEqual(h, hasher.final());
}

test "hash union" {
    const Foo = union(enum) {
        a: u32,
        b: bool,
        c: u32,
        d: void,
    };

    const a: Foo = .{ .a = 18 };
    var b: Foo = .{ .b = true };
    const c: Foo = .{ .c = 18 };
    const d: Foo = .d;
    try expectEqual(testHash(a), testHash(a));
    try expect(testHash(a) != testHash(b));
    try expect(testHash(a) != testHash(c));
    try expect(testHash(a) != testHash(d));

    b = .{ .a = 18 };
    try expectEqual(testHash(a), testHash(b));

    b = .d;
    try expectEqual(testHash(d), testHash(b));
}

test "hash vector" {
    const a: @Vector(4, u32) = .{ 1, 2, 3, 4 };
    const b: @Vector(4, u32) = .{ 1, 2, 3, 5 };
    try expectEqual(testHash(a), testHash(a));
    try expect(testHash(a) != testHash(b));

    const c: @Vector(4, u31) = .{ 1, 2, 3, 4 };
    const d: @Vector(4, u31) = .{ 1, 2, 3, 5 };
    try expectEqual(testHash(c), testHash(c));
    try expect(testHash(c) != testHash(d));
}

test "hash error union" {
    const Errors = error{Test};

    const Foo = struct {
        a: u32,
        b: u32,
        c: u32,
    };
    const f: Foo = .{
        .a = 1,
        .b = 2,
        .c = 3,
    };

    const g: Errors!Foo = error.Test;

    try expect(testHash(f) != testHash(g));
    try expectEqual(testHash(f), testHash(Foo{ .a = 1, .b = 2, .c = 3 }));
    try expectEqual(testHash(g), testHash(Errors.Test));
}
