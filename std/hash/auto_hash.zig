const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const meta = std.meta;

/// Provides generic hashing for any eligible type.
/// Only hashes `key` itself, pointers are not followed.
pub fn autoHash(hasher: var, key: var) void {
    const Key = @typeOf(key);
    switch (@typeInfo(Key)) {
        .NoReturn,
        .Opaque,
        .Undefined,
        .ArgTuple,
        .Void,
        .Null,
        .BoundFn,
        .ComptimeFloat,
        .ComptimeInt,
        .Type,
        .EnumLiteral,
        .Frame,
        => @compileError("cannot hash this type"),

        // Help the optimizer see that hashing an int is easy by inlining!
        // TODO Check if the situation is better after #561 is resolved.
        .Int => @inlineCall(hasher.update, std.mem.asBytes(&key)),

        .Float => |info| autoHash(hasher, @bitCast(@IntType(false, info.bits), key)),

        .Bool => autoHash(hasher, @boolToInt(key)),
        .Enum => autoHash(hasher, @enumToInt(key)),
        .ErrorSet => autoHash(hasher, @errorToInt(key)),
        .AnyFrame, .Fn => autoHash(hasher, @ptrToInt(key)),

        .Pointer => |info| switch (info.size) {
            builtin.TypeInfo.Pointer.Size.One,
            builtin.TypeInfo.Pointer.Size.Many,
            builtin.TypeInfo.Pointer.Size.C,
            => autoHash(hasher, @ptrToInt(key)),

            builtin.TypeInfo.Pointer.Size.Slice => {
                autoHash(hasher, key.ptr);
                autoHash(hasher, key.len);
            },
        },

        .Optional => if (key) |k| autoHash(hasher, k),

        .Array => {
            // TODO detect via a trait when Key has no padding bits to
            // hash it as an array of bytes.
            // Otherwise, hash every element.
            for (key) |element| {
                autoHash(hasher, element);
            }
        },

        .Vector => |info| {
            if (info.child.bit_count % 8 == 0) {
                // If there's no unused bits in the child type, we can just hash
                // this as an array of bytes.
                hasher.update(mem.asBytes(&key));
            } else {
                // Otherwise, hash every element.
                // TODO remove the copy to an array once field access is done.
                const array: [info.len]info.child = key;
                comptime var i: u32 = 0;
                inline while (i < info.len) : (i += 1) {
                    autoHash(hasher, array[i]);
                }
            }
        },

        .Struct => |info| {
            // TODO detect via a trait when Key has no padding bits to
            // hash it as an array of bytes.
            // Otherwise, hash every field.
            inline for (info.fields) |field| {
                // We reuse the hash of the previous field as the seed for the
                // next one so that they're dependant.
                autoHash(hasher, @field(key, field.name));
            }
        },

        .Union => |info| blk: {
            if (info.tag_type) |tag_type| {
                const tag = meta.activeTag(key);
                const s = autoHash(hasher, tag);
                inline for (info.fields) |field| {
                    const enum_field = field.enum_field.?;
                    if (enum_field.value == @enumToInt(tag)) {
                        autoHash(hasher, @field(key, enum_field.name));
                        // TODO use a labelled break when it does not crash the compiler.
                        // break :blk;
                        return;
                    }
                }
                unreachable;
            } else @compileError("cannot hash untagged union type: " ++ @typeName(Key) ++ ", provide your own hash function");
        },

        .ErrorUnion => blk: {
            const payload = key catch |err| {
                autoHash(hasher, err);
                break :blk;
            };
            autoHash(hasher, payload);
        },
    }
}

const testing = std.testing;
const Wyhash = std.hash.Wyhash;

fn testAutoHash(key: var) u64 {
    // Any hash could be used here, for testing autoHash.
    var hasher = Wyhash.init(0);
    autoHash(&hasher, key);
    return hasher.final();
}

test "autoHash slice" {
    // Allocate one array dynamically so that we're assured it is not merged
    // with the other by the optimization passes.
    const array1 = try std.heap.direct_allocator.create([6]u32);
    defer std.heap.direct_allocator.destroy(array1);
    array1.* = [_]u32{ 1, 2, 3, 4, 5, 6 };
    const array2 = [_]u32{ 1, 2, 3, 4, 5, 6 };
    const a = array1[0..];
    const b = array2[0..];
    const c = array1[0..3];
    testing.expect(testAutoHash(a) == testAutoHash(a));
    testing.expect(testAutoHash(a) != testAutoHash(array1));
    testing.expect(testAutoHash(a) != testAutoHash(b));
    testing.expect(testAutoHash(a) != testAutoHash(c));
}

test "testAutoHash optional" {
    const a: ?u32 = 123;
    const b: ?u32 = null;
    testing.expectEqual(testAutoHash(a), testAutoHash(u32(123)));
    testing.expect(testAutoHash(a) != testAutoHash(b));
    testing.expectEqual(testAutoHash(b), 0);
}

test "testAutoHash array" {
    const a = [_]u32{ 1, 2, 3 };
    const h = testAutoHash(a);
    var hasher = Wyhash.init(0);
    autoHash(&hasher, u32(1));
    autoHash(&hasher, u32(2));
    autoHash(&hasher, u32(3));
    testing.expectEqual(h, hasher.final());
}

test "testAutoHash struct" {
    const Foo = struct {
        a: u32 = 1,
        b: u32 = 2,
        c: u32 = 3,
    };
    const f = Foo{};
    const h = testAutoHash(f);
    var hasher = Wyhash.init(0);
    autoHash(&hasher, u32(1));
    autoHash(&hasher, u32(2));
    autoHash(&hasher, u32(3));
    testing.expectEqual(h, hasher.final());
}

test "testAutoHash union" {
    const Foo = union(enum) {
        A: u32,
        B: f32,
        C: u32,
    };

    const a = Foo{ .A = 18 };
    var b = Foo{ .B = 12.34 };
    const c = Foo{ .C = 18 };
    testing.expect(testAutoHash(a) == testAutoHash(a));
    testing.expect(testAutoHash(a) != testAutoHash(b));
    testing.expect(testAutoHash(a) != testAutoHash(c));

    b = Foo{ .A = 18 };
    testing.expect(testAutoHash(a) == testAutoHash(b));
}

test "testAutoHash vector" {
    const a: @Vector(4, u32) = [_]u32{ 1, 2, 3, 4 };
    const b: @Vector(4, u32) = [_]u32{ 1, 2, 3, 5 };
    const c: @Vector(4, u31) = [_]u31{ 1, 2, 3, 4 };
    testing.expect(testAutoHash(a) == testAutoHash(a));
    testing.expect(testAutoHash(a) != testAutoHash(b));
    testing.expect(testAutoHash(a) != testAutoHash(c));
}

test "testAutoHash error union" {
    const Errors = error{Test};
    const Foo = struct {
        a: u32 = 1,
        b: u32 = 2,
        c: u32 = 3,
    };
    const f = Foo{};
    const g: Errors!Foo = Errors.Test;
    testing.expect(testAutoHash(f) != testAutoHash(g));
    testing.expect(testAutoHash(f) == testAutoHash(Foo{}));
    testing.expect(testAutoHash(g) == testAutoHash(Errors.Test));
}
