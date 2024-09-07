const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const math = std.math;
const mem = std.mem;

/// Given a type and value, cast the value to the type as c would.
pub fn cast(comptime DestType: type, target: anytype) DestType {
    // this function should behave like transCCast in translate-c, except it's for macros
    const SourceType = @TypeOf(target);
    switch (@typeInfo(DestType)) {
        .@"fn" => return castToPtr(*const DestType, SourceType, target),
        .pointer => return castToPtr(DestType, SourceType, target),
        .optional => |dest_opt| {
            if (@typeInfo(dest_opt.child) == .pointer) {
                return castToPtr(DestType, SourceType, target);
            } else if (@typeInfo(dest_opt.child) == .@"fn") {
                return castToPtr(?*const dest_opt.child, SourceType, target);
            }
        },
        .int => {
            switch (@typeInfo(SourceType)) {
                .pointer => {
                    return castInt(DestType, @intFromPtr(target));
                },
                .optional => |opt| {
                    if (@typeInfo(opt.child) == .pointer) {
                        return castInt(DestType, @intFromPtr(target));
                    }
                },
                .int => {
                    return castInt(DestType, target);
                },
                .@"fn" => {
                    return castInt(DestType, @intFromPtr(&target));
                },
                .bool => {
                    return @intFromBool(target);
                },
                else => {},
            }
        },
        .float => {
            switch (@typeInfo(SourceType)) {
                .int => return @as(DestType, @floatFromInt(target)),
                .float => return @as(DestType, @floatCast(target)),
                .bool => return @as(DestType, @floatFromInt(@intFromBool(target))),
                else => {},
            }
        },
        .@"union" => |info| {
            inline for (info.fields) |field| {
                if (field.type == SourceType) return @unionInit(DestType, field.name, target);
            }
            @compileError("cast to union type '" ++ @typeName(DestType) ++ "' from type '" ++ @typeName(SourceType) ++ "' which is not present in union");
        },
        .bool => return cast(usize, target) != 0,
        else => {},
    }
    return @as(DestType, target);
}

fn castInt(comptime DestType: type, target: anytype) DestType {
    const dest = @typeInfo(DestType).int;
    const source = @typeInfo(@TypeOf(target)).int;

    if (dest.bits < source.bits)
        return @as(DestType, @bitCast(@as(std.meta.Int(source.signedness, dest.bits), @truncate(target))))
    else
        return @as(DestType, @bitCast(@as(std.meta.Int(source.signedness, dest.bits), target)));
}

fn castPtr(comptime DestType: type, target: anytype) DestType {
    return @constCast(@volatileCast(@alignCast(@ptrCast(target))));
}

fn castToPtr(comptime DestType: type, comptime SourceType: type, target: anytype) DestType {
    switch (@typeInfo(SourceType)) {
        .int => {
            return @as(DestType, @ptrFromInt(castInt(usize, target)));
        },
        .comptime_int => {
            if (target < 0)
                return @as(DestType, @ptrFromInt(@as(usize, @bitCast(@as(isize, @intCast(target))))))
            else
                return @as(DestType, @ptrFromInt(@as(usize, @intCast(target))));
        },
        .pointer => {
            return castPtr(DestType, target);
        },
        .optional => |target_opt| {
            if (@typeInfo(target_opt.child) == .pointer) {
                return castPtr(DestType, target);
            }
        },
        else => {},
    }
    return @as(DestType, target);
}

fn ptrInfo(comptime PtrType: type) std.builtin.Type.Pointer {
    return switch (@typeInfo(PtrType)) {
        .optional => |opt_info| @typeInfo(opt_info.child).pointer,
        .pointer => |ptr_info| ptr_info,
        else => unreachable,
    };
}

test "cast" {
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
}

/// Given a value returns its size as C's sizeof operator would.
pub fn sizeof(target: anytype) usize {
    const T: type = if (@TypeOf(target) == type) target else @TypeOf(target);
    switch (@typeInfo(T)) {
        .float, .int, .@"struct", .@"union", .array, .bool, .vector => return @sizeOf(T),
        .@"fn" => {
            // sizeof(main) in C returns 1
            return 1;
        },
        .null => return @sizeOf(*anyopaque),
        .void => {
            // Note: sizeof(void) is 1 on clang/gcc and 0 on MSVC.
            return 1;
        },
        .@"opaque" => {
            if (T == anyopaque) {
                // Note: sizeof(void) is 1 on clang/gcc and 0 on MSVC.
                return 1;
            } else {
                @compileError("Cannot use C sizeof on opaque type " ++ @typeName(T));
            }
        },
        .optional => |opt| {
            if (@typeInfo(opt.child) == .pointer) {
                return sizeof(opt.child);
            } else {
                @compileError("Cannot use C sizeof on non-pointer optional " ++ @typeName(T));
            }
        },
        .pointer => |ptr| {
            if (ptr.size == .Slice) {
                @compileError("Cannot use C sizeof on slice type " ++ @typeName(T));
            }
            // for strings, sizeof("a") returns 2.
            // normal pointer decay scenarios from C are handled
            // in the .array case above, but strings remain literals
            // and are therefore always pointers, so they need to be
            // specially handled here.
            if (ptr.size == .One and ptr.is_const and @typeInfo(ptr.child) == .array) {
                const array_info = @typeInfo(ptr.child).array;
                if ((array_info.child == u8 or array_info.child == u16) and
                    array_info.sentinel != null and
                    @as(*align(1) const array_info.child, @ptrCast(array_info.sentinel.?)).* == 0)
                {
                    // length of the string plus one for the null terminator.
                    return (array_info.len + 1) * @sizeOf(array_info.child);
                }
            }
            // When zero sized pointers are removed, this case will no
            // longer be reachable and can be deleted.
            if (@sizeOf(T) == 0) {
                return @sizeOf(*anyopaque);
            }
            return @sizeOf(T);
        },
        .comptime_float => return @sizeOf(f64), // TODO c_double #3999
        .comptime_int => {
            // TODO to get the correct result we have to translate
            // `1073741824 * 4` as `int(1073741824) *% int(4)` since
            // sizeof(1073741824 * 4) != sizeof(4294967296).

            // TODO test if target fits in int, long or long long
            return @sizeOf(c_int);
        },
        else => @compileError("std.meta.sizeof does not support type " ++ @typeName(T)),
    }
}

test "sizeof" {
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

pub const CIntLiteralBase = enum { decimal, octal, hex };

/// Deprecated: use `CIntLiteralBase`
pub const CIntLiteralRadix = CIntLiteralBase;

fn PromoteIntLiteralReturnType(comptime SuffixType: type, comptime number: comptime_int, comptime base: CIntLiteralBase) type {
    const signed_decimal = [_]type{ c_int, c_long, c_longlong, c_ulonglong };
    const signed_oct_hex = [_]type{ c_int, c_uint, c_long, c_ulong, c_longlong, c_ulonglong };
    const unsigned = [_]type{ c_uint, c_ulong, c_ulonglong };

    const list: []const type = if (@typeInfo(SuffixType).int.signedness == .unsigned)
        &unsigned
    else if (base == .decimal)
        &signed_decimal
    else
        &signed_oct_hex;

    var pos = mem.indexOfScalar(type, list, SuffixType).?;

    while (pos < list.len) : (pos += 1) {
        if (number >= math.minInt(list[pos]) and number <= math.maxInt(list[pos])) {
            return list[pos];
        }
    }
    @compileError("Integer literal is too large");
}

/// Promote the type of an integer literal until it fits as C would.
pub fn promoteIntLiteral(
    comptime SuffixType: type,
    comptime number: comptime_int,
    comptime base: CIntLiteralBase,
) PromoteIntLiteralReturnType(SuffixType, number, base) {
    return number;
}

test "promoteIntLiteral" {
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

/// Convert from clang __builtin_shufflevector index to Zig @shuffle index
/// clang requires __builtin_shufflevector index arguments to be integer constants.
/// negative values for `this_index` indicate "don't care".
/// clang enforces that `this_index` is less than the total number of vector elements
/// See https://ziglang.org/documentation/master/#shuffle
/// See https://clang.llvm.org/docs/LanguageExtensions.html#langext-builtin-shufflevector
pub fn shuffleVectorIndex(comptime this_index: c_int, comptime source_vector_len: usize) i32 {
    const positive_index = std.math.cast(usize, this_index) orelse return undefined;
    if (positive_index < source_vector_len) return @as(i32, @intCast(this_index));
    const b_index = positive_index - source_vector_len;
    return ~@as(i32, @intCast(b_index));
}

test "shuffleVectorIndex" {
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

/// Constructs a [*c] pointer with the const and volatile annotations
/// from SelfType for pointing to a C flexible array of ElementType.
pub fn FlexibleArrayType(comptime SelfType: type, comptime ElementType: type) type {
    switch (@typeInfo(SelfType)) {
        .pointer => |ptr| {
            return @Type(.{ .pointer = .{
                .size = .C,
                .is_const = ptr.is_const,
                .is_volatile = ptr.is_volatile,
                .alignment = @alignOf(ElementType),
                .address_space = .generic,
                .child = ElementType,
                .is_allowzero = true,
                .sentinel = null,
            } });
        },
        else => |info| @compileError("Invalid self type \"" ++ @tagName(info) ++ "\" for flexible array getter: " ++ @typeName(SelfType)),
    }
}

test "Flexible Array Type" {
    const Container = extern struct {
        size: usize,
    };

    try testing.expectEqual(FlexibleArrayType(*Container, c_int), [*c]c_int);
    try testing.expectEqual(FlexibleArrayType(*const Container, c_int), [*c]const c_int);
    try testing.expectEqual(FlexibleArrayType(*volatile Container, c_int), [*c]volatile c_int);
    try testing.expectEqual(FlexibleArrayType(*const volatile Container, c_int), [*c]const volatile c_int);
}

/// C `%` operator for signed integers
/// C standard states: "If the quotient a/b is representable, the expression (a/b)*b + a%b shall equal a"
/// The quotient is not representable if denominator is zero, or if numerator is the minimum integer for
/// the type and denominator is -1. C has undefined behavior for those two cases; this function has safety
/// checked undefined behavior
pub fn signedRemainder(numerator: anytype, denominator: anytype) @TypeOf(numerator, denominator) {
    std.debug.assert(@typeInfo(@TypeOf(numerator, denominator)).int.signedness == .signed);
    if (denominator > 0) return @rem(numerator, denominator);
    return numerator - @divTrunc(numerator, denominator) * denominator;
}

pub const Macros = struct {
    pub fn U_SUFFIX(comptime n: comptime_int) @TypeOf(promoteIntLiteral(c_uint, n, .decimal)) {
        return promoteIntLiteral(c_uint, n, .decimal);
    }

    fn L_SUFFIX_ReturnType(comptime number: anytype) type {
        switch (@typeInfo(@TypeOf(number))) {
            .int, .comptime_int => return @TypeOf(promoteIntLiteral(c_long, number, .decimal)),
            .float, .comptime_float => return c_longdouble,
            else => @compileError("Invalid value for L suffix"),
        }
    }
    pub fn L_SUFFIX(comptime number: anytype) L_SUFFIX_ReturnType(number) {
        switch (@typeInfo(@TypeOf(number))) {
            .int, .comptime_int => return promoteIntLiteral(c_long, number, .decimal),
            .float, .comptime_float => @compileError("TODO: c_longdouble initialization from comptime_float not supported"),
            else => @compileError("Invalid value for L suffix"),
        }
    }

    pub fn UL_SUFFIX(comptime n: comptime_int) @TypeOf(promoteIntLiteral(c_ulong, n, .decimal)) {
        return promoteIntLiteral(c_ulong, n, .decimal);
    }

    pub fn LL_SUFFIX(comptime n: comptime_int) @TypeOf(promoteIntLiteral(c_longlong, n, .decimal)) {
        return promoteIntLiteral(c_longlong, n, .decimal);
    }

    pub fn ULL_SUFFIX(comptime n: comptime_int) @TypeOf(promoteIntLiteral(c_ulonglong, n, .decimal)) {
        return promoteIntLiteral(c_ulonglong, n, .decimal);
    }

    pub fn F_SUFFIX(comptime f: comptime_float) f32 {
        return @as(f32, f);
    }

    pub fn WL_CONTAINER_OF(ptr: anytype, sample: anytype, comptime member: []const u8) @TypeOf(sample) {
        return @fieldParentPtr(member, ptr);
    }

    /// A 2-argument function-like macro defined as #define FOO(A, B) (A)(B)
    /// could be either: cast B to A, or call A with the value B.
    pub fn CAST_OR_CALL(a: anytype, b: anytype) switch (@typeInfo(@TypeOf(a))) {
        .type => a,
        .@"fn" => |fn_info| fn_info.return_type orelse void,
        else => |info| @compileError("Unexpected argument type: " ++ @tagName(info)),
    } {
        switch (@typeInfo(@TypeOf(a))) {
            .type => return cast(a, b),
            .@"fn" => return a(b),
            else => unreachable, // return type will be a compile error otherwise
        }
    }

    pub inline fn DISCARD(x: anytype) void {
        _ = x;
    }
};

/// Integer promotion described in C11 6.3.1.1.2
fn PromotedIntType(comptime T: type) type {
    return switch (T) {
        bool, u8, i8, c_short => c_int,
        c_ushort => if (@sizeOf(c_ushort) == @sizeOf(c_int)) c_uint else c_int,
        c_int, c_uint, c_long, c_ulong, c_longlong, c_ulonglong => T,
        else => if (T == comptime_int) {
            @compileError("Cannot promote `" ++ @typeName(T) ++ "`; a fixed-size number type is required");
        } else if (@typeInfo(T) == .int) {
            @compileError("Cannot promote `" ++ @typeName(T) ++ "`; a C ABI type is required");
        } else {
            @compileError("Attempted to promote invalid type `" ++ @typeName(T) ++ "`");
        },
    };
}

/// C11 6.3.1.1.1
fn integerRank(comptime T: type) u8 {
    return switch (T) {
        bool => 0,
        u8, i8 => 1,
        c_short, c_ushort => 2,
        c_int, c_uint => 3,
        c_long, c_ulong => 4,
        c_longlong, c_ulonglong => 5,
        else => @compileError("integer rank not supported for `" ++ @typeName(T) ++ "`"),
    };
}

fn ToUnsigned(comptime T: type) type {
    return switch (T) {
        c_int => c_uint,
        c_long => c_ulong,
        c_longlong => c_ulonglong,
        else => @compileError("Cannot convert `" ++ @typeName(T) ++ "` to unsigned"),
    };
}

/// "Usual arithmetic conversions" from C11 standard 6.3.1.8
fn ArithmeticConversion(comptime A: type, comptime B: type) type {
    if (A == c_longdouble or B == c_longdouble) return c_longdouble;
    if (A == f80 or B == f80) return f80;
    if (A == f64 or B == f64) return f64;
    if (A == f32 or B == f32) return f32;

    const A_Promoted = PromotedIntType(A);
    const B_Promoted = PromotedIntType(B);
    comptime {
        std.debug.assert(integerRank(A_Promoted) >= integerRank(c_int));
        std.debug.assert(integerRank(B_Promoted) >= integerRank(c_int));
    }

    if (A_Promoted == B_Promoted) return A_Promoted;

    const a_signed = @typeInfo(A_Promoted).int.signedness == .signed;
    const b_signed = @typeInfo(B_Promoted).int.signedness == .signed;

    if (a_signed == b_signed) {
        return if (integerRank(A_Promoted) > integerRank(B_Promoted)) A_Promoted else B_Promoted;
    }

    const SignedType = if (a_signed) A_Promoted else B_Promoted;
    const UnsignedType = if (!a_signed) A_Promoted else B_Promoted;

    if (integerRank(UnsignedType) >= integerRank(SignedType)) return UnsignedType;

    if (std.math.maxInt(SignedType) >= std.math.maxInt(UnsignedType)) return SignedType;

    return ToUnsigned(SignedType);
}

test "ArithmeticConversion" {
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
}

pub const MacroArithmetic = struct {
    pub fn div(a: anytype, b: anytype) ArithmeticConversion(@TypeOf(a), @TypeOf(b)) {
        const ResType = ArithmeticConversion(@TypeOf(a), @TypeOf(b));
        const a_casted = cast(ResType, a);
        const b_casted = cast(ResType, b);
        switch (@typeInfo(ResType)) {
            .float => return a_casted / b_casted,
            .int => return @divTrunc(a_casted, b_casted),
            else => unreachable,
        }
    }

    pub fn rem(a: anytype, b: anytype) ArithmeticConversion(@TypeOf(a), @TypeOf(b)) {
        const ResType = ArithmeticConversion(@TypeOf(a), @TypeOf(b));
        const a_casted = cast(ResType, a);
        const b_casted = cast(ResType, b);
        switch (@typeInfo(ResType)) {
            .int => {
                if (@typeInfo(ResType).int.signedness == .signed) {
                    return signedRemainder(a_casted, b_casted);
                } else {
                    return a_casted % b_casted;
                }
            },
            else => unreachable,
        }
    }
};

test "Macro suffix functions" {
    try testing.expect(@TypeOf(Macros.F_SUFFIX(1)) == f32);

    try testing.expect(@TypeOf(Macros.U_SUFFIX(1)) == c_uint);
    if (math.maxInt(c_ulong) > math.maxInt(c_uint)) {
        try testing.expect(@TypeOf(Macros.U_SUFFIX(math.maxInt(c_uint) + 1)) == c_ulong);
    }
    if (math.maxInt(c_ulonglong) > math.maxInt(c_ulong)) {
        try testing.expect(@TypeOf(Macros.U_SUFFIX(math.maxInt(c_ulong) + 1)) == c_ulonglong);
    }

    try testing.expect(@TypeOf(Macros.L_SUFFIX(1)) == c_long);
    if (math.maxInt(c_long) > math.maxInt(c_int)) {
        try testing.expect(@TypeOf(Macros.L_SUFFIX(math.maxInt(c_int) + 1)) == c_long);
    }
    if (math.maxInt(c_longlong) > math.maxInt(c_long)) {
        try testing.expect(@TypeOf(Macros.L_SUFFIX(math.maxInt(c_long) + 1)) == c_longlong);
    }

    try testing.expect(@TypeOf(Macros.UL_SUFFIX(1)) == c_ulong);
    if (math.maxInt(c_ulonglong) > math.maxInt(c_ulong)) {
        try testing.expect(@TypeOf(Macros.UL_SUFFIX(math.maxInt(c_ulong) + 1)) == c_ulonglong);
    }

    try testing.expect(@TypeOf(Macros.LL_SUFFIX(1)) == c_longlong);
    try testing.expect(@TypeOf(Macros.ULL_SUFFIX(1)) == c_ulonglong);
}

test "WL_CONTAINER_OF" {
    const S = struct {
        a: u32 = 0,
        b: u32 = 0,
    };
    const x = S{};
    const y = S{};
    const ptr = Macros.WL_CONTAINER_OF(&x.b, &y, "b");
    try testing.expectEqual(&x, ptr);
}

test "CAST_OR_CALL casting" {
    const arg: c_int = 1000;
    const casted = Macros.CAST_OR_CALL(u8, arg);
    try testing.expectEqual(cast(u8, arg), casted);

    const S = struct {
        x: u32 = 0,
    };
    var s: S = .{};
    const casted_ptr = Macros.CAST_OR_CALL(*u8, &s);
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

    Macros.CAST_OR_CALL(Helper.returnsVoid, true);
    try testing.expectEqual(true, Helper.last_val);
    Macros.CAST_OR_CALL(Helper.returnsVoid, false);
    try testing.expectEqual(false, Helper.last_val);

    try testing.expectEqual(Helper.returnsBool(1), Macros.CAST_OR_CALL(Helper.returnsBool, @as(f32, 1)));
    try testing.expectEqual(Helper.returnsBool(-1), Macros.CAST_OR_CALL(Helper.returnsBool, @as(f32, -1)));

    try testing.expectEqual(Helper.identity(@as(c_uint, 100)), Macros.CAST_OR_CALL(Helper.identity, @as(c_uint, 100)));
}

test "Extended C ABI casting" {
    if (math.maxInt(c_long) > math.maxInt(c_char)) {
        try testing.expect(@TypeOf(Macros.L_SUFFIX(@as(c_char, math.maxInt(c_char) - 1))) == c_long); // c_char
    }
    if (math.maxInt(c_long) > math.maxInt(c_short)) {
        try testing.expect(@TypeOf(Macros.L_SUFFIX(@as(c_short, math.maxInt(c_short) - 1))) == c_long); // c_short
    }

    if (math.maxInt(c_long) > math.maxInt(c_ushort)) {
        try testing.expect(@TypeOf(Macros.L_SUFFIX(@as(c_ushort, math.maxInt(c_ushort) - 1))) == c_long); //c_ushort
    }

    if (math.maxInt(c_long) > math.maxInt(c_int)) {
        try testing.expect(@TypeOf(Macros.L_SUFFIX(@as(c_int, math.maxInt(c_int) - 1))) == c_long); // c_int
    }

    if (math.maxInt(c_long) > math.maxInt(c_uint)) {
        try testing.expect(@TypeOf(Macros.L_SUFFIX(@as(c_uint, math.maxInt(c_uint) - 1))) == c_long); // c_uint
        try testing.expect(@TypeOf(Macros.L_SUFFIX(math.maxInt(c_uint) + 1)) == c_long); // comptime_int -> c_long
    }

    if (math.maxInt(c_longlong) > math.maxInt(c_long)) {
        try testing.expect(@TypeOf(Macros.L_SUFFIX(@as(c_long, math.maxInt(c_long) - 1))) == c_long); // c_long
        try testing.expect(@TypeOf(Macros.L_SUFFIX(math.maxInt(c_long) + 1)) == c_longlong); // comptime_int -> c_longlong
    }
}
