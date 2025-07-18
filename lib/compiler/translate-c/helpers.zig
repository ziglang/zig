const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const math = std.math;

const helpers = @import("helpers");

const cast = helpers.cast;

test cast {
    var i = @as(i64, 10);

    try testing.expect(cast(*u8, 16) == @as(*u8, @ptrFromInt(16)));
    try testing.expect(cast(*u64, &i).* == @as(u64, 10));
    try testing.expect(cast(*i64, @as(?*align(1) i64, &i)) == &i);

    try testing.expect(cast(?*u8, 2) == @as(*u8, @ptrFromInt(2)));
    try testing.expect(cast(?*i64, @as(*align(1) i64, &i)) == &i);
    try testing.expect(cast(?*i64, @as(?*align(1) i64, &i)) == &i);

    try testing.expectEqual(@as(u32, 4), cast(u32, @as(*u32, @ptrFromInt(4))));
    try testing.expectEqual(@as(u32, 4), cast(u32, @as(?*u32, @ptrFromInt(4))));
    try testing.expectEqual(@as(u32, 10), cast(u32, @as(u64, 10)));

    try testing.expectEqual(@as(i32, @bitCast(@as(u32, 0x8000_0000))), cast(i32, @as(u32, 0x8000_0000)));

    try testing.expectEqual(@as(*u8, @ptrFromInt(2)), cast(*u8, @as(*const u8, @ptrFromInt(2))));
    try testing.expectEqual(@as(*u8, @ptrFromInt(2)), cast(*u8, @as(*volatile u8, @ptrFromInt(2))));

    try testing.expectEqual(@as(?*anyopaque, @ptrFromInt(2)), cast(?*anyopaque, @as(*u8, @ptrFromInt(2))));

    var foo: c_int = -1;
    _ = &foo;
    try testing.expect(cast(*anyopaque, -1) == @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))))));
    try testing.expect(cast(*anyopaque, foo) == @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))))));
    try testing.expect(cast(?*anyopaque, -1) == @as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))))));
    try testing.expect(cast(?*anyopaque, foo) == @as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))))));

    const FnPtr = ?*align(1) const fn (*anyopaque) void;
    try testing.expect(cast(FnPtr, 0) == @as(FnPtr, @ptrFromInt(@as(usize, 0))));
    try testing.expect(cast(FnPtr, foo) == @as(FnPtr, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))))));

    const complexFunction = struct {
        fn f(_: ?*anyopaque, _: c_uint, _: ?*const fn (?*anyopaque) callconv(.c) c_uint, _: ?*anyopaque, _: c_uint, _: [*c]c_uint) callconv(.c) usize {
            return 0;
        }
    }.f;

    const SDL_FunctionPointer = ?*const fn () callconv(.c) void;
    const fn_ptr = cast(SDL_FunctionPointer, complexFunction);
    try testing.expect(fn_ptr != null);
}

const sizeof = helpers.sizeof;

test sizeof {
    const S = extern struct { a: u32 };

    const ptr_size = @sizeOf(*anyopaque);

    try testing.expect(sizeof(u32) == 4);
    try testing.expect(sizeof(@as(u32, 2)) == 4);
    try testing.expect(sizeof(2) == @sizeOf(c_int));

    try testing.expect(sizeof(2.0) == @sizeOf(f64));

    try testing.expect(sizeof(S) == 4);

    try testing.expect(sizeof([_]u32{ 4, 5, 6 }) == 12);
    try testing.expect(sizeof([3]u32) == 12);
    try testing.expect(sizeof([3:0]u32) == 16);
    try testing.expect(sizeof(&[_]u32{ 4, 5, 6 }) == ptr_size);

    try testing.expect(sizeof(*u32) == ptr_size);
    try testing.expect(sizeof([*]u32) == ptr_size);
    try testing.expect(sizeof([*c]u32) == ptr_size);
    try testing.expect(sizeof(?*u32) == ptr_size);
    try testing.expect(sizeof(?[*]u32) == ptr_size);
    try testing.expect(sizeof(*anyopaque) == ptr_size);
    try testing.expect(sizeof(*void) == ptr_size);
    try testing.expect(sizeof(null) == ptr_size);

    try testing.expect(sizeof("foobar") == 7);
    try testing.expect(sizeof(&[_:0]u16{ 'f', 'o', 'o', 'b', 'a', 'r' }) == 14);
    try testing.expect(sizeof(*const [4:0]u8) == 5);
    try testing.expect(sizeof(*[4:0]u8) == ptr_size);
    try testing.expect(sizeof([*]const [4:0]u8) == ptr_size);
    try testing.expect(sizeof(*const *const [4:0]u8) == ptr_size);
    try testing.expect(sizeof(*const [4]u8) == ptr_size);

    if (false) { // TODO
        try testing.expect(sizeof(&sizeof) == @sizeOf(@TypeOf(&sizeof)));
        try testing.expect(sizeof(sizeof) == 1);
    }

    try testing.expect(sizeof(void) == 1);
    try testing.expect(sizeof(anyopaque) == 1);
}

const promoteIntLiteral = helpers.promoteIntLiteral;

test promoteIntLiteral {
    const signed_hex = promoteIntLiteral(c_int, math.maxInt(c_int) + 1, .hex);
    try testing.expectEqual(c_uint, @TypeOf(signed_hex));

    if (math.maxInt(c_longlong) == math.maxInt(c_int)) return;

    const signed_decimal = promoteIntLiteral(c_int, math.maxInt(c_int) + 1, .decimal);
    const unsigned = promoteIntLiteral(c_uint, math.maxInt(c_uint) + 1, .hex);

    if (math.maxInt(c_long) > math.maxInt(c_int)) {
        try testing.expectEqual(c_long, @TypeOf(signed_decimal));
        try testing.expectEqual(c_ulong, @TypeOf(unsigned));
    } else {
        try testing.expectEqual(c_longlong, @TypeOf(signed_decimal));
        try testing.expectEqual(c_ulonglong, @TypeOf(unsigned));
    }
}

const shuffleVectorIndex = helpers.shuffleVectorIndex;

test shuffleVectorIndex {
    const vector_len: usize = 4;

    _ = shuffleVectorIndex(-1, vector_len);

    try testing.expect(shuffleVectorIndex(0, vector_len) == 0);
    try testing.expect(shuffleVectorIndex(1, vector_len) == 1);
    try testing.expect(shuffleVectorIndex(2, vector_len) == 2);
    try testing.expect(shuffleVectorIndex(3, vector_len) == 3);

    try testing.expect(shuffleVectorIndex(4, vector_len) == -1);
    try testing.expect(shuffleVectorIndex(5, vector_len) == -2);
    try testing.expect(shuffleVectorIndex(6, vector_len) == -3);
    try testing.expect(shuffleVectorIndex(7, vector_len) == -4);
}

const FlexibleArrayType = helpers.FlexibleArrayType;

test FlexibleArrayType {
    const Container = extern struct {
        size: usize,
    };

    try testing.expectEqual(FlexibleArrayType(*Container, c_int), [*c]c_int);
    try testing.expectEqual(FlexibleArrayType(*const Container, c_int), [*c]const c_int);
    try testing.expectEqual(FlexibleArrayType(*volatile Container, c_int), [*c]volatile c_int);
    try testing.expectEqual(FlexibleArrayType(*const volatile Container, c_int), [*c]const volatile c_int);
}

const signedRemainder = helpers.signedRemainder;

test signedRemainder {
    // TODO add test
    return error.SkipZigTest;
}

const ArithmeticConversion = helpers.ArithmeticConversion;

test ArithmeticConversion {
    // Promotions not necessarily the same for other platforms
    if (builtin.target.cpu.arch != .x86_64 or builtin.target.os.tag != .linux) return error.SkipZigTest;

    const Test = struct {
        /// Order of operands should not matter for arithmetic conversions
        fn checkPromotion(comptime A: type, comptime B: type, comptime Expected: type) !void {
            try std.testing.expect(ArithmeticConversion(A, B) == Expected);
            try std.testing.expect(ArithmeticConversion(B, A) == Expected);
        }
    };

    try Test.checkPromotion(c_longdouble, c_int, c_longdouble);
    try Test.checkPromotion(c_int, f64, f64);
    try Test.checkPromotion(f32, bool, f32);

    try Test.checkPromotion(bool, c_short, c_int);
    try Test.checkPromotion(c_int, c_int, c_int);
    try Test.checkPromotion(c_short, c_int, c_int);

    try Test.checkPromotion(c_int, c_long, c_long);

    try Test.checkPromotion(c_ulonglong, c_uint, c_ulonglong);

    try Test.checkPromotion(c_uint, c_int, c_uint);

    try Test.checkPromotion(c_uint, c_long, c_long);

    try Test.checkPromotion(c_ulong, c_longlong, c_ulonglong);

    // stdint.h
    try Test.checkPromotion(u8, i8, c_int);
    try Test.checkPromotion(u16, i16, c_int);
    try Test.checkPromotion(i32, c_int, c_int);
    try Test.checkPromotion(u32, c_int, c_uint);
    try Test.checkPromotion(i64, c_int, c_long);
    try Test.checkPromotion(u64, c_int, c_ulong);
    try Test.checkPromotion(isize, c_int, c_long);
    try Test.checkPromotion(usize, c_int, c_ulong);
}

const F_SUFFIX = helpers.F_SUFFIX;

test F_SUFFIX {
    try testing.expect(@TypeOf(F_SUFFIX(1)) == f32);
}

const U_SUFFIX = helpers.U_SUFFIX;

test U_SUFFIX {
    try testing.expect(@TypeOf(U_SUFFIX(1)) == c_uint);
    if (math.maxInt(c_ulong) > math.maxInt(c_uint)) {
        try testing.expect(@TypeOf(U_SUFFIX(math.maxInt(c_uint) + 1)) == c_ulong);
    }
    if (math.maxInt(c_ulonglong) > math.maxInt(c_ulong)) {
        try testing.expect(@TypeOf(U_SUFFIX(math.maxInt(c_ulong) + 1)) == c_ulonglong);
    }
}

const L_SUFFIX = helpers.L_SUFFIX;

test L_SUFFIX {
    try testing.expect(@TypeOf(L_SUFFIX(1)) == c_long);
    if (math.maxInt(c_long) > math.maxInt(c_int)) {
        try testing.expect(@TypeOf(L_SUFFIX(math.maxInt(c_int) + 1)) == c_long);
    }
    if (math.maxInt(c_longlong) > math.maxInt(c_long)) {
        try testing.expect(@TypeOf(L_SUFFIX(math.maxInt(c_long) + 1)) == c_longlong);
    }
}
const UL_SUFFIX = helpers.UL_SUFFIX;

test UL_SUFFIX {
    try testing.expect(@TypeOf(UL_SUFFIX(1)) == c_ulong);
    if (math.maxInt(c_ulonglong) > math.maxInt(c_ulong)) {
        try testing.expect(@TypeOf(UL_SUFFIX(math.maxInt(c_ulong) + 1)) == c_ulonglong);
    }
}
const LL_SUFFIX = helpers.LL_SUFFIX;

test LL_SUFFIX {
    try testing.expect(@TypeOf(LL_SUFFIX(1)) == c_longlong);
}
const ULL_SUFFIX = helpers.ULL_SUFFIX;

test ULL_SUFFIX {
    try testing.expect(@TypeOf(ULL_SUFFIX(1)) == c_ulonglong);
}

test "Extended C ABI casting" {
    if (math.maxInt(c_long) > math.maxInt(c_char)) {
        try testing.expect(@TypeOf(L_SUFFIX(@as(c_char, math.maxInt(c_char) - 1))) == c_long); // c_char
    }
    if (math.maxInt(c_long) > math.maxInt(c_short)) {
        try testing.expect(@TypeOf(L_SUFFIX(@as(c_short, math.maxInt(c_short) - 1))) == c_long); // c_short
    }

    if (math.maxInt(c_long) > math.maxInt(c_ushort)) {
        try testing.expect(@TypeOf(L_SUFFIX(@as(c_ushort, math.maxInt(c_ushort) - 1))) == c_long); //c_ushort
    }

    if (math.maxInt(c_long) > math.maxInt(c_int)) {
        try testing.expect(@TypeOf(L_SUFFIX(@as(c_int, math.maxInt(c_int) - 1))) == c_long); // c_int
    }

    if (math.maxInt(c_long) > math.maxInt(c_uint)) {
        try testing.expect(@TypeOf(L_SUFFIX(@as(c_uint, math.maxInt(c_uint) - 1))) == c_long); // c_uint
        try testing.expect(@TypeOf(L_SUFFIX(math.maxInt(c_uint) + 1)) == c_long); // comptime_int -> c_long
    }

    if (math.maxInt(c_longlong) > math.maxInt(c_long)) {
        try testing.expect(@TypeOf(L_SUFFIX(@as(c_long, math.maxInt(c_long) - 1))) == c_long); // c_long
        try testing.expect(@TypeOf(L_SUFFIX(math.maxInt(c_long) + 1)) == c_longlong); // comptime_int -> c_longlong
    }
}

const WL_CONTAINER_OF = helpers.WL_CONTAINER_OF;

test WL_CONTAINER_OF {
    const S = struct {
        a: u32 = 0,
        b: u32 = 0,
    };
    const x = S{};
    const y = S{};
    const ptr = WL_CONTAINER_OF(&x.b, &y, "b");
    try testing.expectEqual(&x, ptr);
}

const CAST_OR_CALL = helpers.CAST_OR_CALL;

test "CAST_OR_CALL casting" {
    const arg: c_int = 1000;
    const casted = CAST_OR_CALL(u8, arg);
    try testing.expectEqual(cast(u8, arg), casted);

    const S = struct {
        x: u32 = 0,
    };
    var s: S = .{};
    const casted_ptr = CAST_OR_CALL(*u8, &s);
    try testing.expectEqual(cast(*u8, &s), casted_ptr);
}

test "CAST_OR_CALL calling" {
    const Helper = struct {
        var last_val: bool = false;
        fn returnsVoid(val: bool) void {
            last_val = val;
        }
        fn returnsBool(f: f32) bool {
            return f > 0;
        }
        fn identity(self: c_uint) c_uint {
            return self;
        }
    };

    CAST_OR_CALL(Helper.returnsVoid, true);
    try testing.expectEqual(true, Helper.last_val);
    CAST_OR_CALL(Helper.returnsVoid, false);
    try testing.expectEqual(false, Helper.last_val);

    try testing.expectEqual(Helper.returnsBool(1), CAST_OR_CALL(Helper.returnsBool, @as(f32, 1)));
    try testing.expectEqual(Helper.returnsBool(-1), CAST_OR_CALL(Helper.returnsBool, @as(f32, -1)));

    try testing.expectEqual(Helper.identity(@as(c_uint, 100)), CAST_OR_CALL(Helper.identity, @as(c_uint, 100)));
}
