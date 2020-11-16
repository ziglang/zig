const std = @import("../std.zig");
const mem = std.mem;
const testing = std.testing;

/// Compares two arrays in constant time (for a given length) and returns whether they are equal.
/// This function was designed to compare short cryptographic secrets (MACs, signatures).
/// For all other applications, use mem.eql() instead.
pub fn timingSafeEql(comptime T: type, a: T, b: T) bool {
    switch (@typeInfo(T)) {
        .Array => |info| {
            const C = info.child;
            if (@typeInfo(C) != .Int) {
                @compileError("Elements to be compared must be integers");
            }
            var acc = @as(C, 0);
            for (a) |x, i| {
                acc |= x ^ b[i];
            }
            comptime const s = @typeInfo(C).Int.bits;
            comptime const Cu = std.meta.Int(.unsigned, s);
            comptime const Cext = std.meta.Int(.unsigned, s + 1);
            return @bitCast(bool, @truncate(u1, (@as(Cext, @bitCast(Cu, acc)) -% 1) >> s));
        },
        .Vector => |info| {
            const C = info.child;
            if (@typeInfo(C) != .Int) {
                @compileError("Elements to be compared must be integers");
            }
            const acc = @reduce(.Or, a ^ b);
            comptime const s = @typeInfo(C).Int.bits;
            comptime const Cu = std.meta.Int(.unsigned, s);
            comptime const Cext = std.meta.Int(.unsigned, s + 1);
            return @bitCast(bool, @truncate(u1, (@as(Cext, @bitCast(Cu, acc)) -% 1) >> s));
        },
        else => {
            @compileError("Only arrays and vectors can be compared");
        },
    }
}

/// Sets a slice to zeroes.
/// Prevents the store from being optimized out.
pub fn secureZero(comptime T: type, s: []T) void {
    // NOTE: We do not use a volatile slice cast here since LLVM cannot
    // see that it can be replaced by a memset.
    const ptr = @ptrCast([*]volatile u8, s.ptr);
    const length = s.len * @sizeOf(T);
    @memset(ptr, 0, length);
}

test "crypto.utils.timingSafeEql" {
    var a: [100]u8 = undefined;
    var b: [100]u8 = undefined;
    try std.crypto.randomBytes(a[0..]);
    try std.crypto.randomBytes(b[0..]);
    testing.expect(!timingSafeEql([100]u8, a, b));
    mem.copy(u8, a[0..], b[0..]);
    testing.expect(timingSafeEql([100]u8, a, b));
}

test "crypto.utils.timingSafeEql (vectors)" {
    var a: [100]u8 = undefined;
    var b: [100]u8 = undefined;
    try std.crypto.randomBytes(a[0..]);
    try std.crypto.randomBytes(b[0..]);
    const v1: std.meta.Vector(100, u8) = a;
    const v2: std.meta.Vector(100, u8) = b;
    testing.expect(!timingSafeEql(std.meta.Vector(100, u8), v1, v2));
    const v3: std.meta.Vector(100, u8) = a;
    testing.expect(timingSafeEql(std.meta.Vector(100, u8), v1, v3));
}

test "crypto.utils.secureZero" {
    var a = [_]u8{0xfe} ** 8;
    var b = [_]u8{0xfe} ** 8;

    mem.set(u8, a[0..], 0);
    secureZero(u8, b[0..]);

    testing.expectEqualSlices(u8, a[0..], b[0..]);
}
